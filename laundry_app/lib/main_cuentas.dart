import 'arranque.dart';
import 'modulos/cuentas/modulo_cuentas.dart';

/// Solo este módulo (más el inicio de sesión de S1).
/// Correr: flutter run -d chrome -t lib/main_cuentas.dart
Future<void> main() => arrancarApp([moduloCuentas], presentado: moduloCuentas);
