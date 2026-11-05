import 'package:go_router/go_router.dart';

import 'arranque.dart';
import 'core/arranque/modulo.dart';
import 'modulos/cuentas/modulo_cuentas.dart';
import 'modulos/localizacion/pantallas/landing_screen.dart';

/// Módulo de OCTUBRE de Luis (Sprint 1, «Gestión de cuentas y acceso»),
/// armado con el código nuevo: S1 completo (registro, verificar correo,
/// sesión, redirección por rol, recuperar contraseña, perfil) + la página
/// pública de bienvenida, que en noviembre pasó a S2 Localización.
/// Correr: flutter run -d chrome -t lib/main_octubre_cuentas.dart
final _octubre = Modulo(
  numero: 1,
  id: 'cuentas_octubre',
  nombre: 'Gestión de cuentas y acceso (octubre)',
  responsable: 'Luis Dorado',
  rutas: [
    ...moduloCuentas.rutas,
    GoRoute(path: '/bienvenida', builder: (_, _) => const LandingScreen()),
  ],
  entradas: moduloCuentas.entradas,
);

Future<void> main() => arrancarApp([_octubre], presentado: _octubre);
