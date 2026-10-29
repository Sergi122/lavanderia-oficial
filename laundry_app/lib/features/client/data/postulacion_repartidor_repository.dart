import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/verificacion/backend_verificacion.dart';
import '../../auth/data/auth_repository.dart';
import '../../shared/models/solicitud_repartidor.dart';

/// Todo va en base64 dentro del documento porque el proyecto no usa Firebase
/// Storage. Con carnet (2) + matrícula (1) + licencia de conducir (1) +
/// selfies (3) = 7 fotos en el mismo doc (~7 x 80KB x 4/3 ≈ 750KB en
/// base64), hay que mantener cada una chica para no pasar el límite de
/// 1MB por documento de Firestore.
const maxTamanoFotoRepartidorBytes = 80 * 1024;

final postulacionRepartidorRepositoryProvider =
    Provider<PostulacionRepartidorRepository>((ref) {
      return PostulacionRepartidorRepository(
        ref.watch(firestoreProvider),
        ref.watch(firebaseAuthProvider),
      );
    });

final solicitudRepartidorPropiaProvider = StreamProvider<SolicitudRepartidor?>((
  ref,
) {
  final firestore = ref.watch(firestoreProvider);
  // authState y no currentUser: así el stream se rehace al restaurarse la
  // sesión o al cambiar de cuenta (si no, queda vacío o con la anterior).
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);

  return firestore
      .collection('solicitudes_repartidor')
      .doc(uid)
      .snapshots()
      .map(
        (doc) => doc.exists ? SolicitudRepartidor.fromMap(doc.data()!) : null,
      );
});

class PostulacionRepartidorRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PostulacionRepartidorRepository(this._firestore, this._auth);

  Future<ResultadoVerificacionBackend> enviarSolicitud({
    required String nombre,
    required String telefono,
    required String ci,
    required String placaMoto,
    required Uint8List carnetAnverso,
    required Uint8List carnetReverso,
    required Uint8List matriculaMoto,
    required Uint8List licenciaConducir,
    required Uint8List selfieFrente,
    required Uint8List selfieLado,
  }) async {
    final uid = _auth.currentUser!.uid;

    for (final foto in [
      carnetAnverso,
      carnetReverso,
      matriculaMoto,
      licenciaConducir,
      selfieFrente,
      selfieLado,
    ]) {
      if (foto.length > maxTamanoFotoRepartidorBytes) {
        throw Exception(
          'Una de las fotos pesa demasiado '
          '(máx. ${(maxTamanoFotoRepartidorBytes / 1024).round()} KB).',
        );
      }
    }

    final solicitud = SolicitudRepartidor(
      uid: uid,
      nombre: nombre,
      telefono: telefono,
      ci: ci,
      placaMoto: placaMoto,
      carnetAnversoBase64: base64Encode(carnetAnverso),
      carnetReversoBase64: base64Encode(carnetReverso),
      matriculaMotoBase64: base64Encode(matriculaMoto),
      licenciaConducirBase64: base64Encode(licenciaConducir),
      selfieFrenteBase64: base64Encode(selfieFrente),
      selfieIzquierdaBase64: base64Encode(selfieLado),
      selfieDerechaBase64: base64Encode(selfieLado),
      estado: EstadoSolicitud.pendiente,
    );

    await _firestore
        .collection('solicitudes_repartidor')
        .doc(uid)
        .set(solicitud.toMap());
    return verificarSolicitudBloqueante(tipo: 'repartidor', uid: uid);
  }
}
