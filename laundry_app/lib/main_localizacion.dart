import 'arranque.dart';
import 'modulos/localizacion/modulo_localizacion.dart';

/// Solo este módulo (más el inicio de sesión de S1).
/// Correr: flutter run -d chrome -t lib/main_localizacion.dart
Future<void> main() =>
    arrancarApp([moduloLocalizacion], presentado: moduloLocalizacion);
