// Pasa las instantáneas REALES de Firestore (scripts/simular_pedido.cjs con INSTANTANEAS=…)
// por la misma lógica que usa la app y comprueba que la ciudad 3D quede sincronizada.
// Sin INSTANTANEAS definido el test se omite.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/features/shared/models/pedido.dart';
import 'package:laundry_app/features/shared/widgets/escena_3d_json.dart';
import 'package:laundry_app/features/shared/widgets/escena_datos.dart';

const lavLat = -16.5000, lavLng = -68.1500; // lavandería de prueba

void main() {
  final ruta = Platform.environment['INSTANTANEAS'];
  test('simulación real: la escena sigue al pedido paso a paso', () {
    final snaps = (jsonDecode(File(ruta!).readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final salida = <Map<String, dynamic>>[];
    double? progresoPrevio;
    String? rolPrevio;
    var maxRecoger = 0.0;
    for (final s in snaps) {
      final p = Pedido.fromMap(s['id'] as String, (s['datos'] as Map).cast<String, dynamic>());
      maxRecoger = [maxRecoger, distanciaARecoger(p)].reduce((a, b) => a > b ? a : b);
      final d = escenaDePedido(p, lavLat: lavLat, lavLng: lavLng, distMaxRecoger: maxRecoger);
      final moto = d.motos.isEmpty ? null : d.motos.first;
      salida.add({'paso': s['paso'], 'etapa': p.etapaReparto.name, 'estado': p.estado.name, 'datos': escenaAJson(d)});

      // la moto solo existe mientras viaja, y con el rol de la etapa real
      expect(moto != null, [EtapaReparto.aceptado, EtapaReparto.recogido, EtapaReparto.devolviendo].contains(p.etapaReparto) && p.repartidorUid != null,
          reason: 'moto vs etapa en "${s['paso']}"');
      if (moto != null) {
        expect(moto.rol.name, switch (p.etapaReparto) { EtapaReparto.aceptado => 'recogiendo', EtapaReparto.recogido => 'llevando', _ => 'devolviendo' });
        // el progreso real nunca retrocede dentro de una misma etapa
        if (moto.progreso != null && rolPrevio == moto.rol.name && progresoPrevio != null) {
          expect(moto.progreso!, greaterThanOrEqualTo(progresoPrevio - 1e-9), reason: 'progreso retrocedió en "${s['paso']}"');
        }
        rolPrevio = moto.rol.name;
        progresoPrevio = moto.progreso;
      } else {
        rolPrevio = null;
        progresoPrevio = null;
      }
      // lavado y secado SOLO mientras el estado sea "en proceso"; se acaba al marcarla lista
      expect(d.ciclo, p.estado == EstadoPedido.enProceso && p.etapaReparto == EtapaReparto.enLavanderia, reason: 'ciclo en "${s['paso']}"');
      if (p.estado == EstadoPedido.listo && p.etapaReparto == EtapaReparto.enLavanderia) expect(d.listas, 1);
    }
    // la moto llega de verdad: al final de cada tramo el GPS real da progreso 1
    List<Map<String, dynamic>> deRol(String r) => [for (final o in salida) if ((o['datos']['motos'] as List).isNotEmpty && o['datos']['motos'][0]['rol'] == r) o];
    for (final r in ['recogiendo', 'llevando', 'devolviendo']) {
      final tramo = deRol(r);
      expect(tramo, isNotEmpty, reason: 'hubo tramo $r');
      expect(tramo.last['datos']['motos'][0]['progreso'], 1.0, reason: 'llegada del tramo $r');
      expect(tramo.first['datos']['motos'][0]['progreso'], lessThan(.3), reason: 'salida del tramo $r');
    }
    expect(salida.last['datos']['casas'][0]['estado'], 'entregada');
    File('${ruta}.salida.json').writeAsStringSync(jsonEncode(salida));
  }, skip: ruta == null ? 'define INSTANTANEAS' : false);
}
