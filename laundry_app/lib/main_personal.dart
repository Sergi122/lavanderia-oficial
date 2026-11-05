import 'arranque.dart';
import 'modulos/personal/modulo_personal.dart';

/// Solo este módulo (más el inicio de sesión de S1).
/// Correr: flutter run -d chrome -t lib/main_personal.dart
Future<void> main() =>
    arrancarApp([moduloPersonal], presentado: moduloPersonal);
