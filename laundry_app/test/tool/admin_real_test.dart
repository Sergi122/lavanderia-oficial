// Genera los datos que vería el ADMIN con varios pedidos a la vez (una casa por pedido).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/features/shared/models/pedido.dart';
import 'package:laundry_app/features/shared/widgets/escena_3d_json.dart';
import 'package:laundry_app/features/shared/widgets/escena_datos.dart';

void main() {
  final salida = Platform.environment['ADMIN_JSON'];
  test('admin con 6 pedidos en etapas distintas', () {
    Pedido p(String id, Map<String, dynamic> extra) => Pedido.fromMap(id, {
          'lavanderiaId': 'l', 'prendas': {'Camisas': 2}, 'estado': 'recibido', 'tipoEntrega': 'recojoDomicilio',
          'recojoLat': -16.505, 'recojoLng': -68.145, ...extra,
        });
    final pedidos = [
      p('a001', {}),
      p('b002', {'repartidorUid': 'r', 'etapaReparto': 'aceptado', 'repartidorLat': -16.510, 'repartidorLng': -68.140}),
      p('c003', {'repartidorUid': 'r', 'etapaReparto': 'recogido', 'repartidorLat': -16.503, 'repartidorLng': -68.147}),
      p('d004', {'repartidorUid': 'r', 'etapaReparto': 'enLavanderia', 'estado': 'enProceso'}),
      p('e005', {'repartidorUid': 'r', 'etapaReparto': 'enLavanderia', 'estado': 'listo'}),
      p('f006', {'repartidorUid': 'r', 'etapaReparto': 'devolviendo', 'estado': 'listo', 'repartidorLat': -16.502, 'repartidorLng': -68.148}),
      p('g007', {'tipoEntrega': 'clienteLleva'}),
    ];
    final d = escenaDeLavanderia(pedidos, 'Lavandería Central', asignador: AsignadorCasas(), lavLat: -16.500, lavLng: -68.150);
    expect(d.casas.length, 7);
    expect(d.casas.map((c) => c.slot).toSet().length, 7, reason: 'cada pedido tiene su casa');
    expect(d.motos.length, 3, reason: 'aceptado, recogido y devolviendo van en moto');
    expect(d.lavando + d.secando, 1);
    expect(d.listas, 1);
    if (salida != null) File(salida).writeAsStringSync(jsonEncode(escenaAJson(d)));
  });
}
