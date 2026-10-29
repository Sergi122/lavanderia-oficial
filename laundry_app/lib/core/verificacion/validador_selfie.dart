import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

enum PoseSelfie { frente, lado }

extension PoseSelfieLabel on PoseSelfie {
  String get label {
    switch (this) {
      case PoseSelfie.frente:
        return 'de frente';
      case PoseSelfie.lado:
        return 'de perfil';
    }
  }

  String get instruccion {
    switch (this) {
      case PoseSelfie.frente:
        return 'Mira directo a la cámara';
      case PoseSelfie.lado:
        return 'Gira lentamente la cabeza hacia un lado';
    }
  }
}

class ResultadoSelfie {
  final bool valida;
  final String mensaje;
  const ResultadoSelfie(this.valida, this.mensaje);
}

/// Cuánto le falta a una cara ya detectada (de un frame en vivo o de una
/// foto) para cumplir el ÁNGULO de la pose pedida, en el rango 0 (perfecto)
/// a 1 (nada parecido). No mira los ojos: eso se revisa aparte, solo en el
/// instante de la auto-captura, para que un parpadeo de paso no tire abajo
/// el progreso acumulado mientras la persona sostiene la pose.
double _distanciaAnguloPose(Face cara, PoseSelfie pose) {
  final giro = (cara.headEulerAngleY ?? 0).abs();
  final inclinacion = (cara.headEulerAngleX ?? 0).abs();

  switch (pose) {
    case PoseSelfie.frente:
      // Antes toleraba hasta 15°; se amplía a 22° porque nadie se queda
      // perfectamente quieto y ese margen resultaba muy difícil de sostener.
      // Ahora 30°: con 22° la barra casi no avanzaba en celulares reales
      // porque el ML Kit rápido tiene ±5° de ruido incluso con la cara quieta.
      final penalizacionGiro = (giro / 30).clamp(0, 1);
      final penalizacionInclinacion = (inclinacion / 30).clamp(0, 1);
      return penalizacionGiro > penalizacionInclinacion
          ? penalizacionGiro.toDouble()
          : penalizacionInclinacion.toDouble();
    case PoseSelfie.lado:
      // Antes pedía girar 20-28°; se baja a 16-22° para que alcance con un
      // giro de cabeza más natural.
      const giroObjetivo = 22.0;
      if (giro >= 16) return 0;
      return (1 - giro / giroObjetivo).clamp(0, 1).toDouble();
  }
}

bool _ojosAbiertos(Face cara) {
  final ojoIzq = cara.leftEyeOpenProbability ?? 1;
  final ojoDer = cara.rightEyeOpenProbability ?? 1;
  // Antes exigía >= 0.4 de forma continua (cualquier parpadeo tiraba todo
  // el progreso a 0); ahora es un chequeo puntual y más laxo, solo al
  // momento exacto de auto-capturar.
  return ojoIzq >= 0.2 && ojoDer >= 0.2;
}

/// Heurística para rechazar lentes oscuros / gorra / sombrero sin depender
/// de un servicio de pago: ML Kit no tiene un clasificador de accesorios,
/// pero su clasificador de "ojo abierto" y sus contornos de ojos y cejas
/// dependen de verlos con claridad. Si no logra ubicarlos con confianza, es
/// buena señal de que algo los tapa. No es 100% preciso (requiere
/// `enableContours: true` en el detector), pero evita los casos obvios.
bool pareceOcluida(Face cara) {
  // Ya NO se usan los contornos: en modo rápido / resolución baja ML Kit
  // suele no devolverlos aunque la cara esté despejada, y eso dejaba el
  // progreso en 0 para siempre. Solo se mira si pudo clasificar los ojos.
  return cara.leftEyeOpenProbability == null ||
      cara.rightEyeOpenProbability == null;
}

/// true si la cara detectada en este frame ya cumple la pose pedida (se usa
/// tanto para decidir si ya se puede auto-capturar en vivo como para
/// validar una foto ya tomada en el flujo de respaldo).
bool cumplePose(Face cara, PoseSelfie pose) =>
    _distanciaAnguloPose(cara, pose) <=
        (pose == PoseSelfie.frente ? 0.35 : 0.08) &&
    _ojosAbiertos(cara) &&
    !pareceOcluida(cara);

/// Progreso 0..1 para llenar el arco guía mientras se sostiene la pose.
/// Solo depende del ángulo de la cabeza (no de los ojos) para que no
/// retroceda de golpe por un simple parpadeo.
double progresoPose(Face cara, PoseSelfie pose) =>
    1 - _distanciaAnguloPose(cara, pose);

/// Validación automática con IA en el celular (Google ML Kit, gratis y
/// offline) sobre una foto ya guardada — se usa como respaldo en la web,
/// donde no hay cámara en vivo con stream de frames.
Future<ResultadoSelfie> validarSelfie(
  String rutaArchivo,
  PoseSelfie pose,
) async {
  if (kIsWeb) return const ResultadoSelfie(true, '');

  final detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableContours: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  try {
    final inputImage = InputImage.fromFilePath(rutaArchivo);
    final caras = await detector.processImage(inputImage);

    if (caras.isEmpty) {
      return const ResultadoSelfie(
        false,
        'No se detectó ninguna cara. Repite la foto con buena luz y de cerca.',
      );
    }
    if (caras.length > 1) {
      return const ResultadoSelfie(
        false,
        'Se detectó más de una persona. Toma la foto tú solo.',
      );
    }

    if (pareceOcluida(caras.first)) {
      return const ResultadoSelfie(
        false,
        'No se te ve bien la cara. Si usas lentes oscuros, gorra o sombrero, quítatelos e inténtalo de nuevo.',
      );
    }
    if (!cumplePose(caras.first, pose)) {
      return ResultadoSelfie(
        false,
        pose == PoseSelfie.frente
            ? 'Mira directo a la cámara, sin girar ni inclinar la cabeza, con los ojos abiertos.'
            : 'Gira más la cabeza para mostrar el perfil.',
      );
    }
    return const ResultadoSelfie(true, '');
  } catch (e) {
    debugPrint('No se pudo validar la selfie con ML Kit, se deja pasar: $e');
    return const ResultadoSelfie(true, '');
  } finally {
    await detector.close();
  }
}

class ResultadoLentes {
  final bool hayLentes;
  final String etiquetas;
  const ResultadoLentes(this.hayLentes, this.etiquetas);
}

/// ML Kit de caras no sabe si hay lentes, así que se usa el etiquetador de
/// imágenes (modelo base incluido en la app, offline): entre sus etiquetas
/// están "Glasses" y "Sunglasses". Se aplica a la foto ya tomada, no a cada
/// frame. Si falla, no bloquea (queda para el verificador humano).
Future<ResultadoLentes> detectarLentes(String rutaArchivo) async {
  if (kIsWeb) return const ResultadoLentes(false, '');
  final etiquetador = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.2),
  );
  try {
    final etiquetas = await etiquetador.processImage(
      InputImage.fromFilePath(rutaArchivo),
    );
    final resumen = etiquetas
        .take(6)
        .map((e) => '${e.label} ${e.confidence.toStringAsFixed(2)}')
        .join(', ');
    debugPrint('verif: etiquetas -> $resumen');
    final hay = etiquetas.any(
      (e) =>
          RegExp(
            r'glass|eyewear|goggle',
            caseSensitive: false,
          ).hasMatch(e.label) &&
          e.confidence >= 0.45,
    );
    return ResultadoLentes(hay, resumen);
  } catch (e) {
    debugPrint('verif: no se pudo etiquetar: $e');
    return const ResultadoLentes(false, '');
  } finally {
    await etiquetador.close();
  }
}
