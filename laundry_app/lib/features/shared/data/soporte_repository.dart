import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../models/ticket_soporte.dart';

/// Tickets abiertos por cualquier admin, visibles para el superadmin
/// ("Contáctanos" en el dashboard del admin → bandeja del CEO).
final ticketsAbiertosProvider = StreamProvider<List<TicketSoporte>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('tickets_soporte')
      .orderBy('creadoEn', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => TicketSoporte.fromMap(d.id, d.data()))
            .toList(),
      );
});

/// Tickets del usuario actual (sin orderBy para no exigir índice compuesto:
/// se ordenan aquí, son pocos por persona).
final misTicketsProvider = StreamProvider<List<TicketSoporte>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('tickets_soporte')
      .where('autorUid', isEqualTo: uid)
      .snapshots()
      .map((snap) {
        final lista = snap.docs
            .map((d) => TicketSoporte.fromMap(d.id, d.data()))
            .toList();
        lista.sort(
          (a, b) => (b.creadoEn ?? DateTime(2100)).compareTo(
            a.creadoEn ?? DateTime(2100),
          ),
        );
        return lista;
      });
});

final soporteRepositoryProvider = Provider<SoporteRepository>((ref) {
  return SoporteRepository(ref.watch(firestoreProvider));
});

class SoporteRepository {
  final FirebaseFirestore _firestore;

  SoporteRepository(this._firestore);

  Future<void> crearTicket({
    required String autorUid,
    required String autorNombre,
    required String lavanderiaId,
    required String lavanderiaNombre,
    required String asunto,
    required String mensaje,
    String rolAutor = 'admin',
    String categoria = '',
    String? pedidoId,
  }) {
    return _firestore.collection('tickets_soporte').add({
      'rolAutor': rolAutor,
      'categoria': categoria,
      'pedidoId': pedidoId,
      'respuesta': '',
      'autorUid': autorUid,
      'autorNombre': autorNombre,
      'lavanderiaId': lavanderiaId,
      'lavanderiaNombre': lavanderiaNombre,
      'asunto': asunto,
      'mensaje': mensaje,
      'estado': 'abierto',
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> marcarResuelto(String ticketId, {String respuesta = ''}) {
    return _firestore.collection('tickets_soporte').doc(ticketId).update({
      'estado': 'resuelto',
      if (respuesta.isNotEmpty) 'respuesta': respuesta,
    });
  }
}
