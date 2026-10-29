import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'clasificador_tipos.dart';

bool get clasificadorDisponible => true;

Interpreter? _interprete;
List<String>? _etiquetas;

Future<void> _cargar() async {
  _interprete ??= await Interpreter.fromAsset(rutaModeloPrendas);
  _etiquetas ??= (await rootBundle.loadString(rutaEtiquetasPrendas))
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

/// Recorte cuadrado central y 224×224, igual que en el entrenamiento. El
/// modelo trae su propia normalización: recibe píxeles 0..255.
Float32List _entrada(Uint8List bytes) {
  final original = img.decodeImage(bytes);
  if (original == null) throw const FormatException('Imagen no válida');
  final foto = img.bakeOrientation(original);
  final lado = foto.width < foto.height ? foto.width : foto.height;
  final recorte = img.copyCrop(
    foto,
    x: (foto.width - lado) ~/ 2,
    y: (foto.height - lado) ~/ 2,
    width: lado,
    height: lado,
  );
  final chica = img.copyResize(
    recorte,
    width: ladoEntradaModelo,
    height: ladoEntradaModelo,
    interpolation: img.Interpolation.average,
  );
  final datos = Float32List(ladoEntradaModelo * ladoEntradaModelo * 3);
  var i = 0;
  for (final p in chica) {
    datos[i++] = p.r.toDouble();
    datos[i++] = p.g.toDouble();
    datos[i++] = p.b.toDouble();
  }
  return datos;
}

Future<List<PrediccionPrenda>> clasificarPrenda(Uint8List imagen) async {
  await _cargar();
  final etiquetas = _etiquetas!;
  final entrada = _entrada(imagen)
      .reshape([1, ladoEntradaModelo, ladoEntradaModelo, 3]);
  final salida = [List<double>.filled(etiquetas.length, 0)];
  _interprete!.run(entrada, salida);
  return ordenarPredicciones(etiquetas, salida.first);
}
