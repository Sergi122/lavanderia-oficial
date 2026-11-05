import 'arranque.dart';
import 'modulos/lavanderia/modulo_lavanderia.dart';

/// Solo este módulo (más el inicio de sesión de S1).
/// Correr: flutter run -d chrome -t lib/main_lavanderia.dart
Future<void> main() =>
    arrancarApp([moduloLavanderia], presentado: moduloLavanderia);
