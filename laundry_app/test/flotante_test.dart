import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/core/widgets/flotante.dart';
import 'package:laundry_app/features/client/presentation/nube_acciones.dart';

void main() {
  testWidgets('Flotante no bloquea los toques del hijo y reacciona al cursor', (tester) async {
    var toques = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Flotante(child: ElevatedButton(onPressed: () => toques++, child: const Text('Pedir'))),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Pedir'));
    expect(toques, 1);
    // el cursor encima inclina el widget (la transformación cambia) sin romper nada
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Pedir')) + const Offset(20, 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
  });

  testWidgets('la nube de acciones redirige cada botón a su formulario', (tester) async {
    final pulsados = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: NubeAcciones(acciones: [
            AccionNube(Icons.add, 'Nuevo pedido', () => pulsados.add('pedido'), principal: true),
            AccionNube(Icons.person_outline, 'Mi perfil', () => pulsados.add('perfil')),
            AccionNube(Icons.work_outline, 'Trabaja con nosotros', () => pulsados.add('trabaja')),
          ]),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Nuevo pedido'));
    await tester.tap(find.text('Mi perfil'));
    await tester.tap(find.text('Trabaja con nosotros'));
    expect(pulsados, ['pedido', 'perfil', 'trabaja']);
  });
}
