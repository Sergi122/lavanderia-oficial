// IA de reconocimiento de prendas (MobileNetV2 + TensorFlow Lite).
// En Android/iOS corre con tflite_flutter; en la web, con el mismo .tflite
// en el navegador (tfjs-tflite). Ver ~/lavanderia-app/ia-prendas.
export 'clasificador_tipos.dart';
export 'clasificador_stub.dart'
    if (dart.library.ffi) 'clasificador_movil.dart'
    if (dart.library.js_interop) 'clasificador_web.dart';
