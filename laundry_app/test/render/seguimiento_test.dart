import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/features/client/data/lavanderia_repository.dart';
import 'package:laundry_app/features/client/data/pedido_repository.dart';
import 'package:laundry_app/features/client/presentation/seguimiento_pedido_screen.dart';
import 'package:laundry_app/features/shared/models/lavanderia.dart';
import 'package:laundry_app/features/shared/models/pedido.dart';

Pedido _pedido(Map<String, dynamic> extra) => Pedido.fromMap('p1', {
      'clienteId': 'c',
      'lavanderiaId': 'l1',
      'lavanderiaNombre': 'Lavandería Central',
      'prendas': {'Camisas': 4},
      'estado': 'recibido',
      'tipoEntrega': 'recojoDomicilio',
      'recojoLat': -16.5,
      'recojoLng': -68.15,
      'costoPrendas': 40,
      'costoEnvio': 10,
      ...extra,
    });

void main() {
  final lav = Lavanderia.fromMap('l1', {
    'nombre': 'Lavandería Central',
    'lat': -16.51,
    'lng': -68.14,
  });
  final casos = <String, Map<String, dynamic>>{
    'buscando': {},
    'recogiendo': {'repartidorUid': 'r', 'etapaReparto': 'aceptado', 'repartidorNombre': 'Juan'},
    'llevando': {
      'repartidorUid': 'r',
      'etapaReparto': 'recogido',
      'repartidorLat': -16.505,
      'repartidorLng': -68.145,
    },
    'lavando': {'repartidorUid': 'r', 'etapaReparto': 'enLavanderia', 'estado': 'enProceso'},
    'devolviendo': {'repartidorUid': 'r', 'etapaReparto': 'devolviendo', 'estado': 'listo'},
    'entregado': {'repartidorUid': 'r', 'etapaReparto': 'completada', 'estado': 'entregado', 'entregaCompletada': true},
    'local_listo': {'tipoEntrega': 'clienteLleva', 'estado': 'listo'},
  };
  for (final e in casos.entries) {
    testWidgets('seguimiento ${e.key}', (tester) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          pedidoPorIdProvider('p1').overrideWith((ref) => Stream.value(_pedido(e.value))),
          lavanderiaPorIdProvider('l1').overrideWith((ref) => Stream.value(lav)),
        ],
        child: MaterialApp(home: RepaintBoundary(key: key, child: const SeguimientoPedidoScreen(pedidoId: 'p1'))),
      ));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(tester.takeException(), isNull);
      if (e.key == 'lavando' || e.key == 'devolviendo') {
        await tester.runAsync(() async {
          final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 1.2);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory(Platform.environment['SHOTS_DIR'] ?? '/tmp');
          File('${dir.path}/seg_${e.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
    });
  }
}
