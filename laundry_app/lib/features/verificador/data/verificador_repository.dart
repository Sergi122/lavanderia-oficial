import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../shared/models/solicitud_lavanderia.dart';
import '../../shared/models/solicitud_repartidor.dart';

final solicitudesPendientesProvider = StreamProvider<List<SolicitudLavanderia>>(
  (ref) {
    final firestore = ref.watch(firestoreProvider);
    return firestore
        .collection('solicitudes_lavanderia')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SolicitudLavanderia.fromMap(d.data()))
              .toList(),
        );
  },
);

final solicitudesRepartidorPendientesProvider =
    StreamProvider<List<SolicitudRepartidor>>((ref) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('solicitudes_repartidor')
          .where('estado', isEqualTo: 'pendiente')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => SolicitudRepartidor.fromMap(d.data()))
                .toList(),
          );
    });

final verificadorRepositoryProvider = Provider<VerificadorRepository>((ref) {
  return VerificadorRepository(ref.watch(firestoreProvider));
});

class VerificadorRepository {
  final FirebaseFirestore _firestore;

  VerificadorRepository(this._firestore);

  // El verificador solo confirma la identidad de la persona (carnet vs.
  // selfies). La revisión del local en sí (ubicación, NIT, fotos, posibles
  // duplicados) y la creación de la lavandería/promoción a admin las hace
  // el superadmin como segunda etapa (ver SuperadminRepository.aprobarLavanderia).
  Future<void> confirmarIdentidadLavanderia(String propietarioUid) {
    return _firestore
        .collection('solicitudes_lavanderia')
        .doc(propietarioUid)
        .update({'estado': 'identidadConfirmada'});
  }

  Future<void> rechazar(String propietarioUid, String motivo) {
    return _firestore
        .collection('solicitudes_lavanderia')
        .doc(propietarioUid)
        .update({'estado': 'rechazada', 'motivoRechazo': motivo});
  }

  Future<void> aprobarRepartidor(SolicitudRepartidor solicitud) async {
    final batch = _firestore.batch();

    final usuarioDoc = _firestore.collection('usuarios').doc(solicitud.uid);
    batch.update(usuarioDoc, {'role': 'repartidor'});

    final solicitudDoc = _firestore
        .collection('solicitudes_repartidor')
        .doc(solicitud.uid);
    batch.update(solicitudDoc, {'estado': 'aprobada'});

    await batch.commit();
  }

  Future<void> rechazarRepartidor(String uid, String motivo) {
    return _firestore.collection('solicitudes_repartidor').doc(uid).update({
      'estado': 'rechazada',
      'motivoRechazo': motivo,
    });
  }
}
