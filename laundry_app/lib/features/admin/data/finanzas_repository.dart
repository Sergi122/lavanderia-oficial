import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';

class Egreso {
  final String id;
  final String descripcion;
  final double monto;
  final DateTime? fecha;

  const Egreso({
    required this.id,
    required this.descripcion,
    required this.monto,
    this.fecha,
  });

  factory Egreso.fromMap(String id, Map<String, dynamic> map) {
    return Egreso(
      id: id,
      descripcion: map['descripcion'] as String? ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0,
      fecha: (map['fecha'] as Timestamp?)?.toDate(),
    );
  }
}

final egresosProvider = StreamProvider.family<List<Egreso>, String>((
  ref,
  lavanderiaId,
) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('lavanderias')
      .doc(lavanderiaId)
      .collection('egresos')
      .orderBy('fecha', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => Egreso.fromMap(d.id, d.data())).toList(),
      );
});

final finanzasRepositoryProvider = Provider<FinanzasRepository>((ref) {
  return FinanzasRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

class FinanzasRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FinanzasRepository(this._firestore, this._auth);

  Future<void> agregarEgreso(
    String lavanderiaId,
    String descripcion,
    double monto,
  ) {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collection('lavanderias')
        .doc(lavanderiaId)
        .collection('egresos')
        .add({
          'descripcion': descripcion,
          'monto': monto,
          'fecha': FieldValue.serverTimestamp(),
          'creadoPor': uid,
        });
  }
}
