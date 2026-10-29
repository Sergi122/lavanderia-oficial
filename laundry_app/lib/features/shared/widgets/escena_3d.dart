// En web usa la ciudad 3D (Three.js, /escena3d.html); fuera de web, la escena isométrica 2D.
export 'escena_3d_stub.dart' if (dart.library.js_interop) 'escena_3d_web.dart';
