import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sesion/auth_repository.dart';
import '../modelos/pedido.dart';

final misPedidosProvider = StreamProvider<List<Pedido>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  // authState y no currentUser: así el stream se rehace al restaurarse la
  // sesión o al cambiar de cuenta (si no, queda vacío o con la anterior).
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;

  if (uid == null) return Stream.value(const []);

  return firestore
      .collection('pedidos')
      .where('clienteId', isEqualTo: uid)
      .orderBy('creadoEn', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => Pedido.fromMap(d.id, d.data())).toList(),
      );
});

final pedidosLavanderiaProvider = StreamProvider.family<List<Pedido>, String>((
  ref,
  lavanderiaId,
) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('pedidos')
      .where('lavanderiaId', isEqualTo: lavanderiaId)
      .orderBy('creadoEn', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => Pedido.fromMap(d.id, d.data())).toList(),
      );
});

final pedidoPorIdProvider = StreamProvider.family<Pedido?, String>((ref, id) {
  return ref
      .watch(firestoreProvider)
      .collection('pedidos')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Pedido.fromMap(d.id, d.data()!) : null);
});

final comprobanteEntregaProvider = FutureProvider.family<String?, String>((
  ref,
  id,
) async {
  final doc = await ref
      .watch(firestoreProvider)
      .collection('pedidos')
      .doc(id)
      .collection('comprobante')
      .doc('foto')
      .get();
  return doc.data()?['fotoBase64'] as String?;
});

final pedidoRepositoryProvider = Provider<PedidoRepository>((ref) {
  return PedidoRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

class PedidoRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PedidoRepository(this._firestore, this._auth);

  /// Devuelve el id del pedido creado.
  Future<String> crearPedido({
    String clienteNombre = '',
    required String lavanderiaId,
    required String lavanderiaNombre,
    required Map<String, int> prendas,
    required String notas,
    required TipoEntrega tipoEntrega,
    required String direccionRecojo,
    double? recojoLat,
    double? recojoLng,
    required double costoPrendas,
    required double costoEnvio,
    ModoCobroRegular modoRopaRegular = ModoCobroRegular.pieza,
    double cantidadRopaRegular = 0,
  }) async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('pedidos').add({
      'clienteId': uid,
      'clienteNombre': clienteNombre,
      'lavanderiaId': lavanderiaId,
      'lavanderiaNombre': lavanderiaNombre,
      'prendas': prendas,
      'notas': notas,
      'estado': 'recibido',
      'creadoEn': FieldValue.serverTimestamp(),
      'tipoEntrega': tipoEntrega.name,
      'direccionRecojo': direccionRecojo,
      'recojoLat': recojoLat,
      'recojoLng': recojoLng,
      'costoPrendas': costoPrendas,
      'costoEnvio': costoEnvio,
      'modoRopaRegular': modoRopaRegular.name,
      'cantidadRopaRegular': cantidadRopaRegular,
      'repartidorUid': null,
      'entregaCompletada': false,
      'calificacionLavanderia': null,
    });
    return doc.id;
  }

  /// El cliente dejó su ropa en el mostrador (pedidos "yo llevo mis prendas").
  Future<void> marcarRopaRecibida(String pedidoId) {
    return _firestore.collection('pedidos').doc(pedidoId).update({
      'ropaRecibidaEn': FieldValue.serverTimestamp(),
      'ropaRecibidaPor': _auth.currentUser?.uid,
    });
  }

  Future<void> actualizarEstado(
    String pedidoId,
    EstadoPedido nuevoEstado, {
    double? costoPrendasConfirmado,
  }) {
    return _firestore.collection('pedidos').doc(pedidoId).update({
      'estado': nuevoEstado.name,
      if (costoPrendasConfirmado != null) ...{
        'costoPrendas': costoPrendasConfirmado,
        'precioConfirmado': true,
      },
    });
  }

  Future<void> calificar(
    String pedidoId, {
    required String lavanderiaId,
    required int calificacionLavanderia,
    int? calificacionRepartidor,
    String comentario = '',
  }) async {
    final uid = _auth.currentUser!.uid;
    final batch = _firestore.batch();

    batch.update(_firestore.collection('pedidos').doc(pedidoId), {
      'calificacionLavanderia': calificacionLavanderia,
      // ignore: use_null_aware_elements (el valor es nullable, no la key; el operador '?' no aplica aquí)
      if (calificacionRepartidor != null)
        'calificacionRepartidor': calificacionRepartidor,
      'comentarioCalificacion': comentario,
    });

    // Copia pública y mínima para poder calcular el promedio sin exponer
    // el resto de los datos del pedido a otros clientes.
    batch.set(
      _firestore
          .collection('lavanderias')
          .doc(lavanderiaId)
          .collection('calificaciones')
          .doc(pedidoId),
      {
        'autorUid': uid,
        'estrellas': calificacionLavanderia,
        'comentario': comentario,
        'fecha': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }
}
