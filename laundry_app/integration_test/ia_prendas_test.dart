import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:laundry_app/features/shared/ia/clasificador_prendas.dart';

import 'fotos_prueba.dart';

/// Corre el modelo TFLite real en el dispositivo con fotos del set de prueba.
/// Uso: flutter test integration_test/ia_prendas_test.dart -d <celular>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la IA reconoce prendas en el celular', (tester) async {
    WidgetsFlutterBinding.ensureInitialized();
    var aciertos = 0;
    for (final e in fotosPrueba.entries) {
      final t = Stopwatch()..start();
      final r = await clasificarPrenda(base64Decode(e.value));
      t.stop();
      final top = r.first;
      if (top.clase == e.key) aciertos++;
      debugPrint(
        'IA_PRENDA ${e.key} -> ${top.clase} '
        '${(top.confianza * 100).round()}% (${t.elapsedMilliseconds} ms)',
      );
    }
    debugPrint('IA_PRENDA aciertos $aciertos/${fotosPrueba.length}');
    expect(aciertos, greaterThanOrEqualTo(fotosPrueba.length - 2));
  });
}
