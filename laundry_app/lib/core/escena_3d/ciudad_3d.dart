// En web: ciudad 3D completa (Three.js, /admin3d.html) en un iframe interactivo.
// Fuera de web no hay ciudad 3D (el admin es una app web).
export 'ciudad_3d_stub.dart' if (dart.library.js_interop) 'ciudad_3d_web.dart';
