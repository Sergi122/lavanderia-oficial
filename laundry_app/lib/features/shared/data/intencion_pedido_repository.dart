import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../models/intencion_pedido.dart';

/// Pedidos que un cliente está armando AHORA para una lavandería. El admin
/// los ve en su ciudad 3D como casas en construcción: se terminan cuando el
/// cliente confirma y se derrumban si cancela.
final intencionesLavanderiaProvider =
    StreamProvider.family<List<IntencionPedido>, String>((ref, lavanderiaId) {
      return ref
          .watch(firestoreProvider)
          .collection('intenciones_pedido')
          .where('lavanderiaId', isEqualTo: lavanderiaId)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => IntencionPedido.fromMap(d.id, d.data()))
                .toList(),
          );
    });

final intencionPedidoRepositoryProvider = Provider<IntencionPedidoRepository>(
  (ref) => IntencionPedidoRepository(ref.watch(firestoreProvider)),
);

class IntencionPedidoRepository {
  final FirebaseFirestore _db;
  IntencionPedidoRepository(this._db);

  /// Un solo documento por cliente (id = uid): si abre otro pedido, reemplaza
  /// al anterior en vez de dejar casas a medio construir por toda la ciudad.
  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('intenciones_pedido').doc(uid);

  Future<void> empezar({
    required String clienteUid,
    required String clienteNombre,
    required String lavanderiaId,
    double? lat,
    double? lng,
  }) {
    return _doc(clienteUid).set({
      'clienteUid': clienteUid,
      'clienteNombre': clienteNombre,
      'lavanderiaId': lavanderiaId,
      'lat': lat,
      'lng': lng,
      'estado': EstadoIntencion.armando.name,
      'pedidoId': null,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> moverPunto(String clienteUid, double lat, double lng) {
    return _doc(clienteUid).update({
      'lat': lat,
      'lng': lng,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> confirmar(String clienteUid, String pedidoId) {
    return _doc(clienteUid).update({
      'estado': EstadoIntencion.confirmada.name,
      'pedidoId': pedidoId,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelar(String clienteUid) {
    return _doc(clienteUid).update({
      'estado': EstadoIntencion.cancelada.name,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }
}
