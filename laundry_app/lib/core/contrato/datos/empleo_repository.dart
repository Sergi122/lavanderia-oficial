import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../verificacion/backend_verificacion.dart';
import '../../sesion/auth_repository.dart';
import '../modelos/solicitud_empleado.dart';

/// Tamaño máximo del CV: Firestore limita cada documento a 1MB y el
/// base64 infla el tamaño ~33%. Con carnet (2) + selfies (3) + CV en el
/// mismo doc, hay que dejar margen para las fotos también.
const maxTamanoCvBytes = 400 * 1024;
const maxTamanoFotoEmpleadoBytes = 80 * 1024;

final empleoRepositoryProvider = Provider<EmpleoRepository>((ref) {
  return EmpleoRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final solicitudEmpleadoPropiaProvider = StreamProvider<SolicitudEmpleado?>((
  ref,
) {
  final firestore = ref.watch(firestoreProvider);
  // authState y no currentUser: así el stream se rehace al restaurarse la
  // sesión o al cambiar de cuenta (si no, queda vacío o con la anterior).
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);

  return firestore
      .collection('solicitudes_empleado')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? SolicitudEmpleado.fromMap(doc.data()!) : null);
});

class EmpleoRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  EmpleoRepository(this._firestore, this._auth);

  // La postulación ya NO promueve al instante: crea una solicitud que debe
  // aprobar el admin de esa lavandería en particular (confirma identidad con
  // carnet + selfies, igual que lavandería/repartidor), para que no cualquiera
  // pueda autoasignarse como empleado de un negocio ajeno.
  Future<ResultadoVerificacionBackend> enviarSolicitud({
    required String nombre,
    required String direccion,
    required int edad,
    required String ci,
    required String telefono,
    required String lavanderiaId,
    required Uint8List archivoCv,
    required String nombreArchivoCv,
    required Uint8List carnetAnverso,
    required Uint8List carnetReverso,
    required Uint8List selfieFrente,
    required Uint8List selfieLado,
  }) async {
    if (archivoCv.length > maxTamanoCvBytes) {
      throw Exception(
        'El CV pesa demasiado (máx. ${(maxTamanoCvBytes / 1024).round()} KB). '
        'Comprime el archivo o sube uno más liviano.',
      );
    }
    for (final foto in [
      carnetAnverso,
      carnetReverso,
      selfieFrente,
      selfieLado,
    ]) {
      if (foto.length > maxTamanoFotoEmpleadoBytes) {
        throw Exception(
          'Una de las fotos pesa demasiado '
          '(máx. ${(maxTamanoFotoEmpleadoBytes / 1024).round()} KB).',
        );
      }
    }

    final uid = _auth.currentUser!.uid;

    final solicitud = SolicitudEmpleado(
      uid: uid,
      nombre: nombre,
      direccion: direccion,
      edad: edad,
      ci: ci,
      telefono: telefono,
      lavanderiaId: lavanderiaId,
      cvNombre: nombreArchivoCv,
      cvBase64: base64Encode(archivoCv),
      carnetAnversoBase64: base64Encode(carnetAnverso),
      carnetReversoBase64: base64Encode(carnetReverso),
      selfieFrenteBase64: base64Encode(selfieFrente),
      selfieIzquierdaBase64: base64Encode(selfieLado),
      selfieDerechaBase64: base64Encode(selfieLado),
      estado: EstadoSolicitud.pendiente,
    );

    await _firestore
        .collection('solicitudes_empleado')
        .doc(uid)
        .set(solicitud.toMap());
    return verificarSolicitudBloqueante(tipo: 'empleado', uid: uid);
  }
}
