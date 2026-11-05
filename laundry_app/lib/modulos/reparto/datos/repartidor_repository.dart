import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sesion/auth_repository.dart';
import '../../../core/contrato/modelos/app_user.dart';
import '../../../core/contrato/modelos/pedido.dart';

List<Pedido> _ordenarPorFecha(List<Pedido> pedidos) {
  return pedidos..sort(
    (a, b) => (b.creadoEn ?? DateTime(0)).compareTo(a.creadoEn ?? DateTime(0)),
  );
}

final pedidosDisponiblesProvider = StreamProvider<List<Pedido>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  // se rehace al cambiar de sesión o de rol (si no, queda con el error de
  // permisos de antes de ser repartidor)
  final rol = ref.watch(
    currentAppUserProvider.select((u) => u.valueOrNull?.role),
  );
  if (rol != UserRole.repartidor) return Stream.value(const []);
  return firestore
      .collection('pedidos')
      .where('tipoEntrega', isEqualTo: 'recojoDomicilio')
      .where('repartidorUid', isNull: true)
      .snapshots()
      .map(
        (snap) => _ordenarPorFecha(
          snap.docs.map((d) => Pedido.fromMap(d.id, d.data())).toList(),
        ),
      );
});

final misEntregasProvider = StreamProvider<List<Pedido>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  // authState y no currentUser: así el stream se rehace al restaurarse la
  // sesión o al cambiar de cuenta (si no, queda vacío o con la anterior).
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);

  return firestore
      .collection('pedidos')
      .where('repartidorUid', isEqualTo: uid)
      .where('entregaCompletada', isEqualTo: false)
      .snapshots()
      .map(
        (snap) => _ordenarPorFecha(
          snap.docs.map((d) => Pedido.fromMap(d.id, d.data())).toList(),
        ),
      );
});

/// Entregas ya cerradas por este repartidor, para su historial y ganancias.
final historialEntregasProvider = StreamProvider<List<Pedido>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  // authState y no currentUser: así el stream se rehace al restaurarse la
  // sesión o al cambiar de cuenta (si no, queda vacío o con la anterior).
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);

  return firestore
      .collection('pedidos')
      .where('repartidorUid', isEqualTo: uid)
      .where('entregaCompletada', isEqualTo: true)
      .snapshots()
      .map(
        (snap) => _ordenarPorFecha(
          snap.docs.map((d) => Pedido.fromMap(d.id, d.data())).toList(),
        ),
      );
});

final repartidorRepositoryProvider = Provider<RepartidorRepository>((ref) {
  return RepartidorRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

class RepartidorRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  RepartidorRepository(this._firestore, this._auth);

  /// Lanza una excepción (por ejemplo si otro repartidor ya lo tomó) que la
  /// UI debe capturar para avisarle al usuario. Guarda nombre y teléfono en el
  /// pedido para que el cliente pueda contactar al repartidor.
  Future<void> aceptarPedido(
    String pedidoId, {
    required String nombre,
    required String telefono,
  }) {
    final uid = _auth.currentUser!.uid;
    return _firestore.collection('pedidos').doc(pedidoId).update({
      'repartidorUid': uid,
      'etapaReparto': EtapaReparto.aceptado.name,
      'repartidorNombre': nombre,
      'repartidorTelefono': telefono,
    });
  }

  /// Avanza un paso (las reglas de Firestore validan que sea el siguiente).
  Future<void> avanzarEtapa(String pedidoId, EtapaReparto nueva) {
    return _firestore.collection('pedidos').doc(pedidoId).update({
      'etapaReparto': nueva.name,
    });
  }

  /// Cierra la entrega: primero sube la foto de comprobante (documento aparte)
  /// y después marca el pedido como completado.
  Future<void> completarEntrega(String pedidoId, String fotoBase64) async {
    final pedido = _firestore.collection('pedidos').doc(pedidoId);
    await pedido.collection('comprobante').doc('foto').set({
      'fotoBase64': fotoBase64,
    });
    await pedido.update({
      'etapaReparto': EtapaReparto.completada.name,
      'entregaCompletada': true,
      'estado': EstadoPedido.entregado.name,
      'tieneComprobante': true,
    });
  }

  Future<void> publicarUbicacion(String pedidoId, double lat, double lng) {
    return _firestore.collection('pedidos').doc(pedidoId).update({
      'repartidorLat': lat,
      'repartidorLng': lng,
      'repartidorActualizadoEn': FieldValue.serverTimestamp(),
    });
  }
}
