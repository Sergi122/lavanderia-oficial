import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sesion/auth_repository.dart';

class Egreso {
  final String id;
  final String descripcion;
  final double monto;
  final DateTime? fecha;

  /// Foto de la factura o recibo (opcional, comprimida, en base64).
  final String facturaBase64;

  const Egreso({
    required this.id,
    required this.descripcion,
    required this.monto,
    this.fecha,
    this.facturaBase64 = '',
  });

  factory Egreso.fromMap(String id, Map<String, dynamic> map) {
    return Egreso(
      id: id,
      descripcion: map['descripcion'] as String? ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0,
      fecha: (map['fecha'] as Timestamp?)?.toDate(),
      facturaBase64: map['facturaBase64'] as String? ?? '',
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
    double monto, {
    DateTime? fecha,
    String facturaBase64 = '',
  }) {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collection('lavanderias')
        .doc(lavanderiaId)
        .collection('egresos')
        .add({
          'descripcion': descripcion,
          'monto': monto,
          // Si el gasto es de otro día (ej. la factura de luz del 05), se
          // guarda esa fecha; si no, la hora del servidor.
          'fecha': fecha == null
              ? FieldValue.serverTimestamp()
              : Timestamp.fromDate(fecha),
          if (facturaBase64.isNotEmpty) 'facturaBase64': facturaBase64,
          'creadoPor': uid,
        });
  }
}
