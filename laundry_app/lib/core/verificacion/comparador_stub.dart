import 'dart:typed_data';

import 'comparador_tipos.dart';

/// En la web no se compara el rostro (la verificación con cámara es solo del
/// celular), así que esto nunca se usa; existe para que la web compile sin
/// `dart:ffi`.
Future<ResultadoComparacion> compararCarnetConSelfie({
  required Uint8List carnetAnverso,
  required Uint8List selfieFrente,
}) async => const ResultadoComparacion(EstadoComparacion.error);
