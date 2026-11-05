import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sesion/auth_repository.dart';
import '../modelos/app_user.dart';
import '../modelos/convocatoria.dart';
import '../modelos/solicitud_empleado.dart';

// Solicitudes pendientes de un empleado para ESTA lavandería en particular
// (el admin solo ve/aprueba a sus propios postulantes, no los de otras).
final solicitudesEmpleadoPendientesProvider =
    StreamProvider.family<List<SolicitudEmpleado>, String>((ref, lavanderiaId) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('solicitudes_empleado')
          .where('lavanderiaId', isEqualTo: lavanderiaId)
          .where('estado', isEqualTo: 'pendiente')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => SolicitudEmpleado.fromMap(d.data()))
                .toList(),
          );
    });

/// Empleados que hoy trabajan en ESTA lavandería (para el panel "Mi equipo":
/// ver salarios, editarlos, o despedir).
final equipoActualProvider = StreamProvider.family<List<AppUser>, String>((
  ref,
  lavanderiaId,
) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('usuarios')
      .where('role', isEqualTo: 'empleado')
      .where('lavanderiaId', isEqualTo: lavanderiaId)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList(),
      );
});

/// Empleados que ya pasaron por el proceso de aprobación alguna vez pero
/// hoy no trabajan en ninguna lavandería (mini "LinkedIn" — cualquier admin
/// los puede ver y contratar directo, sin repetir el papeleo).
final empleadosDisponiblesProvider = StreamProvider<List<AppUser>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('usuarios')
      .where('role', isEqualTo: 'empleado')
      .where('lavanderiaId', isNull: true)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList(),
      );
});

/// Convocatorias abiertas de ESTA lavandería (para gestionarlas en el panel
/// del admin que las publicó).
final convocatoriasDeLavanderiaProvider =
    StreamProvider.family<List<Convocatoria>, String>((ref, lavanderiaId) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('convocatorias')
          .where('lavanderiaId', isEqualTo: lavanderiaId)
          .orderBy('creadoEn', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => Convocatoria.fromMap(d.id, d.data()))
                .toList(),
          );
    });

/// Todas las convocatorias abiertas de cualquier lavandería (para que un
/// empleado sin trabajo las explore y postule).
final convocatoriasAbiertasProvider = StreamProvider<List<Convocatoria>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('convocatorias')
      .where('abierta', isEqualTo: true)
      .orderBy('creadoEn', descending: true)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => Convocatoria.fromMap(d.id, d.data())).toList(),
      );
});

final postulantesDeConvocatoriaProvider =
    StreamProvider.family<List<PostulanteConvocatoria>, String>((
      ref,
      convocatoriaId,
    ) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('convocatorias')
          .doc(convocatoriaId)
          .collection('postulantes')
          .orderBy('fecha', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => PostulanteConvocatoria.fromMap(d.id, d.data()))
                .toList(),
          );
    });

final adminEmpleadosRepositoryProvider = Provider<AdminEmpleadosRepository>((
  ref,
) {
  return AdminEmpleadosRepository(ref.watch(firestoreProvider));
});

class AdminEmpleadosRepository {
  final FirebaseFirestore _firestore;

  AdminEmpleadosRepository(this._firestore);

  Future<void> aprobar(SolicitudEmpleado solicitud) async {
    final batch = _firestore.batch();

    final usuarioDoc = _firestore.collection('usuarios').doc(solicitud.uid);
    batch.update(usuarioDoc, {
      'role': 'empleado',
      'lavanderiaId': solicitud.lavanderiaId,
    });

    final solicitudDoc = _firestore
        .collection('solicitudes_empleado')
        .doc(solicitud.uid);
    batch.update(solicitudDoc, {'estado': 'aprobada'});

    await batch.commit();
  }

  Future<void> rechazar(String uid, String motivo) {
    return _firestore.collection('solicitudes_empleado').doc(uid).update({
      'estado': 'rechazada',
      'motivoRechazo': motivo,
    });
  }

  /// Deja a un empleado de tu propia lavandería sin trabajo (sigue siendo
  /// "empleado" en el sistema, pero queda visible en la bolsa de disponibles).
  Future<void> despedir(String uid) {
    return _firestore.collection('usuarios').doc(uid).update({
      'lavanderiaId': null,
    });
  }

  /// Contrata directo a un empleado que ya está en la bolsa de disponibles
  /// (sin pasar de nuevo por carnet/selfies — ya se verificó una vez).
  Future<void> contratarDisponible(String uid, String lavanderiaId) {
    return _firestore.collection('usuarios').doc(uid).update({
      'lavanderiaId': lavanderiaId,
    });
  }

  /// El admin fija el salario mensual de un empleado de su equipo — se usa
  /// para sumar la planilla automáticamente en Finanzas.
  Future<void> actualizarSalario(String uid, double salario) {
    return _firestore.collection('usuarios').doc(uid).update({
      'salarioEmpleado': salario,
    });
  }

  Future<void> publicarConvocatoria({
    required String lavanderiaId,
    required String lavanderiaNombre,
    required String puesto,
    required double salario,
    required String horario,
    required String descripcion,
  }) {
    return _firestore.collection('convocatorias').add({
      'lavanderiaId': lavanderiaId,
      'lavanderiaNombre': lavanderiaNombre,
      'puesto': puesto,
      'salario': salario,
      'horario': horario,
      'descripcion': descripcion,
      'abierta': true,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cerrarConvocatoria(String convocatoriaId) {
    return _firestore.collection('convocatorias').doc(convocatoriaId).update({
      'abierta': false,
    });
  }

  Future<void> postular(
    String convocatoriaId,
    String uid,
    String nombre,
    String telefono,
    String mensaje,
  ) {
    return _firestore
        .collection('convocatorias')
        .doc(convocatoriaId)
        .collection('postulantes')
        .doc(uid)
        .set({
          'nombre': nombre,
          'telefono': telefono,
          'mensaje': mensaje,
          'fecha': FieldValue.serverTimestamp(),
        });
  }
}
