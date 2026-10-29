import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Guarda las capturas de la prueba en build/capturas_e2e/.
Future<void> main() => integrationDriver(
  onScreenshot: (nombre, bytes, [args]) async {
    final f = File('build/capturas_e2e/$nombre.png');
    await f.create(recursive: true);
    await f.writeAsBytes(bytes);
    return true;
  },
);
