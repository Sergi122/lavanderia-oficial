import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:laundry_app/core/theme/app_theme.dart';
import 'package:laundry_app/features/auth/data/auth_repository.dart';
import 'package:laundry_app/features/shared/models/pedido.dart';
import 'package:laundry_app/features/shared/presentation/registrar_prendas_screen.dart';

import 'fotos_prueba.dart';

/// Prueba de punta a punta del registro de prendas con IA: pantalla real,
/// modelo real (TFLite en Android, tfjs-tflite en la web), base de datos en
/// memoria (no toca Firestore real ni necesita iniciar sesión).
///
/// Android: flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/registrar_prendas_e2e_test.dart -d <celular>
/// Web: igual con -d web-server --browser-name=chrome (chromedriver en :4444)
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el empleado registra prendas con la IA y se guarda el pedido', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('lavanderias').doc('L1').set({
      'nombre': 'Lavandería de Prueba',
      'precios': {'Jeans': 10, 'Vestidos': 15, 'Edredones / cobijas': 30},
      'activo': true,
    });
    final mapa = {
      'clienteId': 'cli1',
      'clienteNombre': 'Ana Prueba',
      'lavanderiaId': 'L1',
      'lavanderiaNombre': 'Lavandería de Prueba',
      'prendas': {'Jeans': 1, 'Vestidos': 1},
      'estado': 'recibido',
      'tipoEntrega': 'clienteLleva',
      'costoPrendas': 3.0, // el celular del cliente mandó un precio falso
      'costoEnvio': 0.0,
      'notas': '',
      'direccionRecojo': '',
    };
    await db.collection('pedidos').doc('PEDIDO1').set(mapa);
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'empleado1'),
    );

    final cola = ['jeans', 'vestido', 'edredon', 'polera'];
    final esperado = {
      'jeans': 'Jeans',
      'vestido': 'Vestidos',
      'edredon': 'Edredones / cobijas',
      'polera': 'Poleras',
    };
    var siguiente = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          firebaseAuthProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: RegistrarPrendasScreen(
            pedido: Pedido.fromMap('PEDIDO1', mapa),
            selectorFoto: (_) async =>
                base64Decode(fotosPrueba[cola[siguiente++]]!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (!kIsWeb) await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('1_inicio');

    Future<void> esperarAnalisis() async {
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty) return;
      }
      fail('la IA no respondió');
    }

    for (final prenda in cola) {
      await tester.tap(find.text('Fotografiar'));
      await tester.pump();
      await esperarAnalisis();
      await tester.pumpAndSettle();
      // si la IA no estaba segura, el recepcionista elige la opción correcta
      final nombre = esperado[prenda]!;
      final yaContada = find.textContaining(nombre).evaluate().isNotEmpty &&
          find.byWidgetPredicate(
            (w) => w is ChoiceChip && w.selected,
          ).evaluate().isNotEmpty;
      final chip = find.widgetWithText(ChoiceChip, nombre);
      final opcion = find.byWidgetPredicate(
        (w) =>
            w is ChoiceChip &&
            w.label is Text &&
            ((w.label as Text).data ?? '').startsWith(nombre),
      );
      debugPrint('E2E foto $prenda: contada sola=$yaContada');
      if (opcion.evaluate().isNotEmpty) {
        final c = tester.widget<ChoiceChip>(opcion.first);
        if (!c.selected) {
          await tester.ensureVisible(opcion.first);
          await tester.tap(opcion.first);
          await tester.pumpAndSettle();
          debugPrint('E2E corregida a mano: $nombre');
        }
      } else if (chip.evaluate().isEmpty) {
        debugPrint('E2E $prenda: la opción correcta no estaba entre las 3');
      }
      await binding.takeScreenshot('2_foto_$prenda');
    }

    await tester.scrollUntilVisible(find.text('Agregar a mano'), 300);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('3_conteo');

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    final guardado = (await db.collection('pedidos').doc('PEDIDO1').get())
        .data()!;
    debugPrint('E2E guardado: prendas=${guardado['prendas']} '
        'costo=${guardado['costoPrendas']} confirmado=${guardado['precioConfirmado']} '
        'porIA=${guardado['prendasPorIA']} recibidaPor=${guardado['ropaRecibidaPor']}');
    expect(guardado['precioConfirmado'], true);
    expect(guardado['ropaRecibidaPor'], 'empleado1');
    expect((guardado['prendas'] as Map)['Jeans'], 1);
    expect((guardado['prendas'] as Map)['Vestidos'], 1);
    expect((guardado['prendas'] as Map)['Edredones / cobijas'], 1);
    expect((guardado['prendas'] as Map)['Poleras'], 1);
    // 10 + 15 + 30 + 5 (Poleras sin precio → por defecto), no los Bs 3 del cliente
    expect(guardado['costoPrendas'], 60);
  });
}
