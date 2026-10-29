import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../shared/models/horario_atencion.dart';
import '../../shared/models/lavanderia.dart';

/// Solo las lavanderías activas (el superadmin puede desactivar una sin
/// borrarla) se ofrecen a los clientes en el mapa y en la landing.
final lavanderiasProvider = StreamProvider<List<Lavanderia>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('lavanderias')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => Lavanderia.fromMap(d.id, d.data()))
            .where((lav) => lav.activo)
            .toList(),
      );
});

final lavanderiaPorIdProvider = StreamProvider.family<Lavanderia?, String>((
  ref,
  lavanderiaId,
) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('lavanderias')
      .doc(lavanderiaId)
      .snapshots()
      .map(
        (doc) => doc.exists ? Lavanderia.fromMap(doc.id, doc.data()!) : null,
      );
});

/// Promedio de estrellas (1-5) calculado del lado del cliente a partir de la
/// subcolección pública `calificaciones`; null si todavía no tiene ninguna.
final calificacionPromedioProvider = StreamProvider.family<double?, String>((
  ref,
  lavanderiaId,
) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('lavanderias')
      .doc(lavanderiaId)
      .collection('calificaciones')
      .snapshots()
      .map((snap) {
        if (snap.docs.isEmpty) return null;
        final suma = snap.docs.fold<int>(
          0,
          (acc, d) => acc + ((d.data()['estrellas'] as num?)?.toInt() ?? 0),
        );
        return suma / snap.docs.length;
      });
});

class Calificacion {
  final int estrellas;
  final String comentario;
  final DateTime? fecha;

  const Calificacion({
    required this.estrellas,
    required this.comentario,
    this.fecha,
  });

  factory Calificacion.fromMap(Map<String, dynamic> map) {
    return Calificacion(
      estrellas: (map['estrellas'] as num?)?.toInt() ?? 0,
      comentario: map['comentario'] as String? ?? '',
      fecha: (map['fecha'] as Timestamp?)?.toDate(),
    );
  }
}

/// Últimas reseñas de clientes (con comentario), para mostrarlas en el
/// dashboard del admin — más recientes primero.
final calificacionesProvider =
    StreamProvider.family<List<Calificacion>, String>((ref, lavanderiaId) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('lavanderias')
          .doc(lavanderiaId)
          .collection('calificaciones')
          .orderBy('fecha', descending: true)
          .limit(20)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => Calificacion.fromMap(d.data())).toList(),
          );
    });

final lavanderiaRepositoryProvider = Provider<LavanderiaRepository>((ref) {
  return LavanderiaRepository(ref.watch(firestoreProvider));
});

class LavanderiaRepository {
  final FirebaseFirestore _firestore;

  LavanderiaRepository(this._firestore);

  Future<void> actualizarLavanderia(
    String lavanderiaId, {
    required List<String> servicios,
    required Map<String, double> precios,
    required Map<String, String> iconosServicios,
    double? descuentoPorDocena,
    double? descuentoMaximoPorcentaje,
    double? precioKg,
    required double costoEnvio,
    double costoKmExtra = 0,
    required bool entregaDomicilio,
    required List<String> fotosBase64,
    required String descripcion,
    required HorarioAtencion horarioAtencion,
    required String temaPanel,
    required String iconoPanel,
  }) {
    return _firestore.collection('lavanderias').doc(lavanderiaId).update({
      'servicios': servicios,
      'precios': precios,
      'iconosServicios': iconosServicios,
      'descuentoPorDocena': descuentoPorDocena,
      'descuentoMaximoPorcentaje': descuentoMaximoPorcentaje,
      'precioKg': precioKg,
      'costoEnvio': costoEnvio,
      'costoKmExtra': costoKmExtra,
      'entregaDomicilio': entregaDomicilio,
      'fotosBase64': fotosBase64,
      'descripcion': descripcion,
      'horarioAtencion': horarioAtencion.toMap(),
      'temaPanel': temaPanel,
      'iconoPanel': iconoPanel,
    });
  }
}
