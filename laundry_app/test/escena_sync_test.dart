import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/features/shared/models/pedido.dart';
import 'package:laundry_app/features/shared/widgets/escena_datos.dart';
import 'package:laundry_app/features/shared/widgets/escena_lavanderia.dart';

// Casa y lavandería ~1.1 km al norte-sur una de otra
const casaLat = -16.5000, casaLng = -68.1500, lavLat = -16.5100, lavLng = -68.1500;

Pedido pedido(Map<String, dynamic> extra) => Pedido.fromMap('abcd1234', {
      'clienteId': 'c',
      'lavanderiaId': 'l',
      'lavanderiaNombre': 'Lav',
      'prendas': {'Camisas': 3},
      'estado': 'recibido',
      'tipoEntrega': 'recojoDomicilio',
      'recojoLat': casaLat,
      'recojoLng': casaLng,
      'costoPrendas': 30,
      'costoEnvio': 10,
      ...extra,
    });

void main() {
  group('progreso real por GPS', () {
    test('llevando: 0 en la casa, ~0.5 a mitad de camino, 1 al llegar', () {
      double p(double lat) => progresoReal(
          pedido({'repartidorUid': 'r', 'etapaReparto': 'recogido', 'repartidorLat': lat, 'repartidorLng': casaLng}),
          lavLat: lavLat, lavLng: lavLng)!;
      expect(p(casaLat), closeTo(0, .02));
      expect(p((casaLat + lavLat) / 2), closeTo(.5, .03));
      expect(p(lavLat), 1.0); // a menos de 25 m = llegó
    });
    test('devolviendo: parte de la lavandería y termina en la casa', () {
      double p(double lat) => progresoReal(
          pedido({'repartidorUid': 'r', 'etapaReparto': 'devolviendo', 'estado': 'listo', 'repartidorLat': lat, 'repartidorLng': casaLng}),
          lavLat: lavLat, lavLng: lavLng)!;
      expect(p(lavLat), closeTo(0, .02));
      expect(p(casaLat), 1.0);
    });
    test('recogiendo: se mide contra la mayor distancia vista', () {
      final p = pedido({'repartidorUid': 'r', 'etapaReparto': 'aceptado', 'repartidorLat': casaLat - .0045, 'repartidorLng': casaLng});
      final d = distanciaARecoger(p); // ~500 m
      expect(d, greaterThan(400));
      expect(progresoReal(p, lavLat: lavLat, lavLng: lavLng, distMaxRecoger: d)!, closeTo(0, .02));
      expect(progresoReal(p, lavLat: lavLat, lavLng: lavLng, distMaxRecoger: d * 2)!, closeTo(.5, .02));
    });
    test('sin GPS devuelve null (la escena hace la demostración)', () {
      expect(progresoReal(pedido({'repartidorUid': 'r', 'etapaReparto': 'recogido'}), lavLat: lavLat, lavLng: lavLng), isNull);
    });
  });

  group('casa del cliente y lavandería', () {
    test('estado de la casa sigue la vida real', () {
      expect(estadoCasa(pedido({})).estado, 'esperandoRepartidor');
      expect(estadoCasa(pedido({'repartidorUid': 'r', 'etapaReparto': 'aceptado'})).estado, 'repartidorCamino');
      expect(estadoCasa(pedido({'repartidorUid': 'r', 'etapaReparto': 'recogido'})).estado, 'ropaEnCamino');
      expect(estadoCasa(pedido({'repartidorUid': 'r', 'etapaReparto': 'enLavanderia', 'estado': 'enProceso'})).estado, 'lavando');
      expect(estadoCasa(pedido({'repartidorUid': 'r', 'etapaReparto': 'devolviendo', 'estado': 'listo'})).estado, 'devolviendo');
      expect(estadoCasa(pedido({'repartidorUid': 'r', 'etapaReparto': 'completada', 'estado': 'entregado', 'entregaCompletada': true})).estado, 'entregada');
      expect(estadoCasa(pedido({'tipoEntrega': 'clienteLleva'})).estado, 'trae');
    });

    test('lavado y secado duran mientras el empleado no marque listo', () {
      final base = {'repartidorUid': 'r', 'etapaReparto': 'enLavanderia'};
      final en = escenaDePedido(pedido({...base, 'estado': 'enProceso'}));
      expect(en.ciclo, isTrue);
      expect(en.lavando, 1);
      expect(en.motos, isEmpty);
      final listo = escenaDePedido(pedido({...base, 'estado': 'listo'}));
      expect(listo.ciclo, isFalse);
      expect(listo.listas, 1);
    });

    test('la moto aparece solo en las etapas de viaje, con rol y progreso reales', () {
      final d = escenaDePedido(
          pedido({'repartidorUid': 'r', 'etapaReparto': 'recogido', 'repartidorLat': (casaLat + lavLat) / 2, 'repartidorLng': casaLng}),
          lavLat: lavLat, lavLng: lavLng);
      expect(d.motos.single.rol, RolMoto.llevando);
      expect(d.motos.single.progreso, closeTo(.5, .03));
      expect(d.rutaLarga, isTrue);
      expect(escenaDePedido(pedido({'repartidorUid': 'r', 'etapaReparto': 'enLavanderia'})).motos, isEmpty);
    });
  });

  group('admin: una casa por pedido', () {
    Pedido p(String id, Map<String, dynamic> extra) => Pedido.fromMap(id, {
          'lavanderiaId': 'l', 'prendas': {'Camisas': 1}, 'estado': 'recibido', 'tipoEntrega': 'recojoDomicilio',
          'recojoLat': casaLat, 'recojoLng': casaLng, ...extra,
        });

    test('cada pedido activo ocupa su propia casa y la conserva', () {
      final asig = AsignadorCasas();
      final a = p('aaaa1111', {});
      final b = p('bbbb2222', {'repartidorUid': 'r', 'etapaReparto': 'recogido', 'repartidorLat': casaLat, 'repartidorLng': casaLng});
      final c = p('cccc3333', {'repartidorUid': 'r', 'etapaReparto': 'enLavanderia', 'estado': 'enProceso'});
      final d1 = escenaDeLavanderia([a, b, c], 'Lav', asignador: asig, lavLat: lavLat, lavLng: lavLng);
      expect(d1.casas.length, 3);
      expect(d1.casas.map((e) => e.slot).toSet().length, 3, reason: 'casas distintas');
      expect(d1.motos.length, 1);
      expect(d1.motos.single.slot, d1.casas.firstWhere((e) => e.etiqueta.startsWith('#BBBB')).slot);
      expect(d1.lavando + d1.secando, 1);
      // el pedido a se entrega: su casa se libera y b y c conservan la suya
      final slotB = d1.casas.firstWhere((e) => e.etiqueta.startsWith('#BBBB')).slot;
      final d2 = escenaDeLavanderia([b, c], 'Lav', asignador: asig, lavLat: lavLat, lavLng: lavLng);
      expect(d2.casas.firstWhere((e) => e.etiqueta.startsWith('#BBBB')).slot, slotB);
      expect(d2.casas.length, 2);
    });

    test('los pedidos entregados no ocupan casa y hay un máximo de 8', () {
      final entregado = p('zzzz0000', {'estado': 'entregado', 'entregaCompletada': true});
      final muchos = [for (var i = 0; i < 12; i++) p('p${i.toString().padLeft(3, '0')}x', {})];
      final d = escenaDeLavanderia([entregado, ...muchos], 'Lav');
      expect(d.casas.length, maxCasasEscena);
      expect(d.casas.any((e) => e.etiqueta.startsWith('#ZZZZ')), isFalse);
    });
  });
}
