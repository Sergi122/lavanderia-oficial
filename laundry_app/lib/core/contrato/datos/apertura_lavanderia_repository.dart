import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../verificacion/backend_verificacion.dart';
import '../../sesion/auth_repository.dart';
import '../modelos/solicitud_lavanderia.dart';

/// Cada imagen se guarda en base64 dentro del documento de Firestore (sin
/// Firebase Storage en el proyecto). Con carnet (2) + selfies (3) + fotos
/// del local (hasta 2) en el mismo doc, cada imagen debe ser chica para no
/// pasar el límite de 1MB por documento.
const maxTamanoFotoBytes = 80 * 1024;
const maxFotosLavanderia = 2;

final aperturaLavanderiaRepositoryProvider =
    Provider<AperturaLavanderiaRepository>((ref) {
      return AperturaLavanderiaRepository(
        ref.watch(firestoreProvider),
        ref.watch(firebaseAuthProvider),
      );
    });

final solicitudPropiaProvider = StreamProvider<SolicitudLavanderia?>((ref) {
  final firestore = ref.watch(firestoreProvider);
  // authState y no currentUser: así el stream se rehace al restaurarse la
  // sesión o al cambiar de cuenta (si no, queda vacío o con la anterior).
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);

  return firestore
      .collection('solicitudes_lavanderia')
      .doc(uid)
      .snapshots()
      .map(
        (doc) => doc.exists ? SolicitudLavanderia.fromMap(doc.data()!) : null,
      );
});

class AperturaLavanderiaRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AperturaLavanderiaRepository(this._firestore, this._auth);

  Future<ResultadoVerificacionBackend> enviarSolicitud({
    required String nombrePropietario,
    required String ciPropietario,
    required String telefonoPropietario,
    required String nombre,
    required String nit,
    required String direccion,
    required double lat,
    required double lng,
    required List<String> servicios,
    required Map<String, double> precios,
    required bool mostrarPrecios,
    double? precioDocena,
    double? precioKg,
    required double costoEnvio,
    required bool entregaDomicilio,
    required List<Uint8List> fotos,
    required Uint8List carnetAnverso,
    required Uint8List carnetReverso,
    required Uint8List selfieFrente,
    required Uint8List selfieLado,
  }) async {
    final uid = _auth.currentUser!.uid;

    for (final foto in [
      ...fotos,
      carnetAnverso,
      carnetReverso,
      selfieFrente,
      selfieLado,
    ]) {
      if (foto.length > maxTamanoFotoBytes) {
        throw Exception(
          'Una de las fotos pesa demasiado (máx. ${(maxTamanoFotoBytes / 1024).round()} KB).',
        );
      }
    }

    final solicitud = SolicitudLavanderia(
      propietarioUid: uid,
      nombrePropietario: nombrePropietario,
      ciPropietario: ciPropietario,
      telefonoPropietario: telefonoPropietario,
      nombre: nombre,
      nit: nit,
      direccion: direccion,
      lat: lat,
      lng: lng,
      servicios: servicios,
      precios: precios,
      mostrarPrecios: mostrarPrecios,
      precioDocena: precioDocena,
      precioKg: precioKg,
      costoEnvio: costoEnvio,
      entregaDomicilio: entregaDomicilio,
      fotosBase64: [for (final f in fotos) base64Encode(f)],
      carnetAnversoBase64: base64Encode(carnetAnverso),
      carnetReversoBase64: base64Encode(carnetReverso),
      selfieFrenteBase64: base64Encode(selfieFrente),
      selfieIzquierdaBase64: base64Encode(selfieLado),
      selfieDerechaBase64: base64Encode(selfieLado),
      estado: EstadoSolicitud.pendiente,
    );

    await _firestore
        .collection('solicitudes_lavanderia')
        .doc(uid)
        .set(solicitud.toMap());
    return verificarSolicitudBloqueante(tipo: 'lavanderia', uid: uid);
  }
}
