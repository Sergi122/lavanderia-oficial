import 'arranque.dart';
import 'modulos/finanzas/modulo_finanzas.dart';

/// Solo este módulo (más el inicio de sesión de S1).
/// Correr: flutter run -d chrome -t lib/main_finanzas.dart
Future<void> main() =>
    arrancarApp([moduloFinanzas], presentado: moduloFinanzas);
