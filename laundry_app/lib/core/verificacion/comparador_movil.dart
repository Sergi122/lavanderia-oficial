import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'comparador_tipos.dart';

Interpreter? _interprete;

Future<Interpreter> _cargarModelo() async {
  return _interprete ??= await Interpreter.fromAsset(
    'assets/models/facenet_512.tflite',
  );
}

/// Detecta la cara más grande de la imagen y devuelve el recorte cuadrado
/// (con un poco de margen) listo para el modelo, o null si no hay cara.
Future<img.Image?> _recortarRostro(Uint8List jpeg) async {
  final original = img.decodeImage(jpeg);
  if (original == null) return null;
  final foto = img.bakeOrientation(original);

  // Se guarda ya con la orientación aplicada para que ML Kit y este recorte
  // vean exactamente la misma imagen.
  final archivo = File(
    '${Directory.systemTemp.path}/rostro_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  final detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.05,
    ),
  );
  try {
    await archivo.writeAsBytes(img.encodeJpg(foto, quality: 95));
    final caras = await detector.processImage(
      InputImage.fromFilePath(archivo.path),
    );
    if (caras.isEmpty) return null;
    caras.sort(
      (a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(
        a.boundingBox.width * a.boundingBox.height,
      ),
    );
    final caja = caras.first.boundingBox;

    // Cuadrado alrededor de la cara; el margen imita el recorte con el que
    // se entrenó el modelo (cara completa con algo de frente y mentón).
    final lado = math.max(caja.width, caja.height) * 1.25;
    final cx = caja.center.dx;
    final cy = caja.center.dy;
    final lienzo = img.Image(width: lado.round(), height: lado.round());
    img.fill(lienzo, color: img.ColorRgb8(0, 0, 0));
    final x0 = (cx - lado / 2).round();
    final y0 = (cy - lado / 2).round();
    // Copia solo la parte de la foto que cae dentro del cuadrado.
    for (var y = 0; y < lienzo.height; y++) {
      final sy = y0 + y;
      if (sy < 0 || sy >= foto.height) continue;
      for (var x = 0; x < lienzo.width; x++) {
        final sx = x0 + x;
        if (sx < 0 || sx >= foto.width) continue;
        lienzo.setPixel(x, y, foto.getPixel(sx, sy));
      }
    }
    return img.copyResize(
      lienzo,
      width: 160,
      height: 160,
      interpolation: img.Interpolation.average,
    );
  } finally {
    await detector.close();
    if (await archivo.exists()) await archivo.delete();
  }
}

Future<List<double>> _embedding(img.Image rostro, Interpreter modelo) async {
  final forma = modelo.getInputTensor(0).shape; // [1, 160, 160, 3]
  final tam = forma[1];
  final r = tam == 160
      ? rostro
      : img.copyResize(rostro, width: tam, height: tam);

  final valores = Float32List(tam * tam * 3);
  var i = 0;
  double suma = 0;
  for (var y = 0; y < tam; y++) {
    for (var x = 0; x < tam; x++) {
      final p = r.getPixel(x, y);
      valores[i++] = p.r.toDouble();
      valores[i++] = p.g.toDouble();
      valores[i++] = p.b.toDouble();
    }
  }
  for (final v in valores) {
    suma += v;
  }
  final media = suma / valores.length;
  double varianza = 0;
  for (final v in valores) {
    varianza += (v - media) * (v - media);
  }
  // "Prewhiten" de FaceNet: (x - media) / desviación.
  final desv = math.max(
    math.sqrt(varianza / valores.length),
    1 / math.sqrt(valores.length),
  );
  for (var k = 0; k < valores.length; k++) {
    valores[k] = (valores[k] - media) / desv;
  }

  final entrada = valores.reshape([1, tam, tam, 3]);
  final dim = modelo.getOutputTensor(0).shape.last;
  final salida = List.filled(dim, 0.0).reshape([1, dim]);
  modelo.run(entrada, salida);

  final v = (salida[0] as List).cast<double>();
  final norma = math.sqrt(v.fold<double>(0, (a, b) => a + b * b));
  return v.map((e) => e / norma).toList();
}

double _coseno(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += a[i] * b[i];
  }
  return s;
}

/// Compara la cara del carnet (anverso) con la selfie de frente, 100% en el
/// celular (modelo FaceNet en TFLite), sin enviar nada a ningún servidor.
Future<ResultadoComparacion> compararCarnetConSelfie({
  required Uint8List carnetAnverso,
  required Uint8List selfieFrente,
}) async {
  if (kIsWeb) return const ResultadoComparacion(EstadoComparacion.error);
  try {
    final modelo = await _cargarModelo();
    final rostroCarnet = await _recortarRostro(carnetAnverso);
    if (rostroCarnet == null)
      return const ResultadoComparacion(EstadoComparacion.sinRostroCarnet);
    final rostroSelfie = await _recortarRostro(selfieFrente);
    if (rostroSelfie == null)
      return const ResultadoComparacion(EstadoComparacion.sinRostroSelfie);

    final a = await _embedding(rostroCarnet, modelo);
    final b = await _embedding(rostroSelfie, modelo);
    final sim = _coseno(a, b);
    debugPrint(
      'verif: similitud carnet-selfie = ${sim.toStringAsFixed(3)} (umbral $umbralSimilitudRostro)',
    );
    return ResultadoComparacion(
      sim >= umbralSimilitudRostro
          ? EstadoComparacion.coincide
          : EstadoComparacion.noCoincide,
      sim,
    );
  } catch (e, st) {
    debugPrint('verif: error comparando rostros: $e\n$st');
    return const ResultadoComparacion(EstadoComparacion.error);
  }
}
