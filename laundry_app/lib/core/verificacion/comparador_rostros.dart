// tflite_flutter usa dart:ffi (no existe en web): en web se usa un stub.
export 'comparador_tipos.dart';
export 'comparador_stub.dart' if (dart.library.ffi) 'comparador_movil.dart';
