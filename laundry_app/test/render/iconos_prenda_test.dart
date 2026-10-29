import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/features/shared/widgets/icono_prenda.dart';

void main() {
  test('cada nombre de servicio tiene un dibujo razonable', () {
    expect(iconoParaPrenda('Jeans'), 'jeans');
    expect(iconoParaPrenda('Sábanas king'), 'ropa_cama');
    expect(iconoParaPrenda('Edredones / cobijas'), 'edredon');
    expect(iconoParaPrenda('Terno de novio'), 'traje_completo');
    expect(iconoParaPrenda('Trajes (por pieza)'), 'traje');
    expect(iconoParaPrenda('Chompas / abrigos'), 'chompa');
    expect(iconoParaPrenda('Vestido de fiesta'), 'vestido');
    expect(iconoParaPrenda('Algo raro'), 'otro');
    expect(iconoParaPrenda('Algo raro', elegidos: {'Algo raro': 'toalla'}), 'toalla');
  });

  testWidgets('las ilustraciones se dibujan', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 380));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF1F7FD),
          body: Wrap(
            children: [
              for (final id in iconosPrenda)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: IconoPrenda(id, tamano: 84),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/iconos_prenda.png'),
    );
  });
}
