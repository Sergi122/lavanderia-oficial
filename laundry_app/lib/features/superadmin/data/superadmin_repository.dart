import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../shared/models/app_user.dart';
import '../../shared/models/lavanderia.dart';
import '../../shared/models/pedido.dart';
import '../../shared/models/solicitud_lavanderia.dart';

final todosLosUsuariosProvider = StreamProvider<List<AppUser>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('usuarios')
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList(),
      );
});

final todasLasLavanderiasProvider = StreamProvider<List<Lavanderia>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('lavanderias')
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => Lavanderia.fromMap(d.id, d.data())).toList(),
      );
});

final pedidosRecientesProvider = StreamProvider<List<Pedido>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('pedidos')
      .orderBy('creadoEn', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => Pedido.fromMap(d.id, d.data())).toList(),
      );
});

class MetricasGlobales {
  final int usuarios;
  final int lavanderias;
  final int pedidos;
  final int repartidoresActivos;

  const MetricasGlobales({
    required this.usuarios,
    required this.lavanderias,
    required this.pedidos,
    required this.repartidoresActivos,
  });
}

final metricasGlobalesProvider = FutureProvider<MetricasGlobales>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final usuarios = await firestore.collection('usuarios').count().get();
  final lavanderias = await firestore.collection('lavanderias').count().get();
  final pedidos = await firestore.collection('pedidos').count().get();
  final repartidores = await firestore
      .collection('usuarios')
      .where('role', isEqualTo: 'repartidor')
      .where('activo', isEqualTo: true)
      .count()
      .get();

  return MetricasGlobales(
    usuarios: usuarios.count ?? 0,
    lavanderias: lavanderias.count ?? 0,
    pedidos: pedidos.count ?? 0,
    repartidoresActivos: repartidores.count ?? 0,
  );
});

// Locales con identidad ya confirmada por el verificador, esperando que el
// superadmin revise el local en sí (ubicación, NIT, fotos, duplicados) antes
// de la aprobación final.
final solicitudesLavanderiaParaSuperadminProvider =
    StreamProvider<List<SolicitudLavanderia>>((ref) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('solicitudes_lavanderia')
          .where('estado', isEqualTo: 'identidadConfirmada')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => SolicitudLavanderia.fromMap(d.data()))
                .toList(),
          );
    });

final superadminRepositoryProvider = Provider<SuperadminRepository>((ref) {
  return SuperadminRepository(ref.watch(firestoreProvider));
});

class SuperadminRepository {
  final FirebaseFirestore _firestore;

  SuperadminRepository(this._firestore);

  Future<void> cambiarRol(String uid, UserRole nuevoRole) {
    return _firestore.collection('usuarios').doc(uid).update({
      'role': nuevoRole.name,
    });
  }

  // Segunda etapa de revisión de un local: crea la lavandería pública y
  // promueve al dueño a admin. Solo procede tras confirmarIdentidadLavanderia.
  Future<void> aprobarLavanderia(SolicitudLavanderia solicitud) async {
    final batch = _firestore.batch();

    final nuevaLavanderia = _firestore.collection('lavanderias').doc();
    batch.set(nuevaLavanderia, solicitud.toLavanderiaMap());

    final usuarioDoc = _firestore
        .collection('usuarios')
        .doc(solicitud.propietarioUid);
    batch.update(usuarioDoc, {
      'role': 'admin',
      'lavanderiaId': nuevaLavanderia.id,
    });

    final solicitudDoc = _firestore
        .collection('solicitudes_lavanderia')
        .doc(solicitud.propietarioUid);
    batch.update(solicitudDoc, {'estado': 'aprobada'});

    await batch.commit();
  }

  Future<void> rechazarLavanderia(String propietarioUid, String motivo) {
    return _firestore
        .collection('solicitudes_lavanderia')
        .doc(propietarioUid)
        .update({'estado': 'rechazada', 'motivoRechazo': motivo});
  }

  Future<void> toggleActivoUsuario(String uid, bool activo) {
    return _firestore.collection('usuarios').doc(uid).update({
      'activo': activo,
    });
  }

  Future<void> toggleActivoLavanderia(String lavanderiaId, bool activo) {
    return _firestore.collection('lavanderias').doc(lavanderiaId).update({
      'activo': activo,
    });
  }
}
