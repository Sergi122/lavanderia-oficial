import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../contrato/modelos/app_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  final firestore = ref.watch(firestoreProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return firestore
          .collection('usuarios')
          .doc(user.uid)
          .snapshots()
          .map(
            (doc) => doc.exists ? AppUser.fromMap(user.uid, doc.data()!) : null,
          );
    },
    loading: () => Stream.value(null),
    error: (_, _) => Stream.value(null),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});

enum MotivoNoEliminar { sesionAntigua, rolConNegocio, pedidosEnCurso }

class EliminarCuentaException implements Exception {
  final MotivoNoEliminar motivo;
  const EliminarCuentaException(this.motivo);

  String get mensaje => switch (motivo) {
    MotivoNoEliminar.sesionAntigua => 'Por seguridad, cierra sesión, vuelve a entrar y repite en los próximos minutos.',
    MotivoNoEliminar.rolConNegocio => 'Las cuentas de lavandería o del equipo se eliminan pidiéndolo por «Contáctanos», para no perder los pedidos de tus clientes.',
    MotivoNoEliminar.pedidosEnCurso => 'Tienes pedidos o entregas en curso. Podrás eliminar tu cuenta cuando terminen.',
  };
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  Future<void> registrar({
    required String nombre,
    required String email,
    required String password,
    required String telefono,
    required String versionTerminos,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    await _firestore
        .collection('usuarios')
        .doc(uid)
        .set(
          AppUser(
            uid: uid,
            nombre: nombre,
            email: email,
            role: UserRole.cliente,
            telefono: telefono,
          ).toMap()..addAll({
            'terminosVersion': versionTerminos,
            'terminosAceptadosEn': FieldValue.serverTimestamp(),
          }),
        );
    // Sin enlace de Firebase: la pantalla de verificación pide el código de
    // 6 dígitos al backend apenas se abre.
  }

  /// Guarda que el usuario aceptó la versión vigente de la política de
  /// privacidad y los términos (usuarios de Google, cuentas antiguas o
  /// cuando cambia la versión).
  Future<void> aceptarTerminos(String uid, String version) {
    return _firestore.collection('usuarios').doc(uid).update({
      'terminosVersion': version,
      'terminosAceptadosEn': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina la cuenta del usuario: su perfil, sus solicitudes (carnet y
  /// selfies), su intención de pedido y por último la cuenta de Auth. Los
  /// pedidos entregados se quedan (contabilidad de la lavandería).
  ///
  /// Firebase exige un inicio de sesión reciente para borrar la cuenta; lo
  /// comprobamos ANTES de tocar Firestore para no dejar una cuenta sin perfil.
  Future<void> eliminarCuenta() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ultimo = user.metadata.lastSignInTime;
    if (ultimo == null ||
        DateTime.now().difference(ultimo) > const Duration(minutes: 4)) {
      throw const EliminarCuentaException(MotivoNoEliminar.sesionAntigua);
    }
    final uid = user.uid;
    final perfil = await _firestore.collection('usuarios').doc(uid).get();
    final rol = perfil.data()?['role'] as String? ?? 'cliente';
    if (!['cliente', 'empleado', 'repartidor'].contains(rol)) {
      throw const EliminarCuentaException(MotivoNoEliminar.rolConNegocio);
    }
    final pedidos = await _firestore
        .collection('pedidos')
        .where('clienteId', isEqualTo: uid)
        .get();
    final encargos = await _firestore
        .collection('pedidos')
        .where('repartidorUid', isEqualTo: uid)
        .where('entregaCompletada', isEqualTo: false)
        .get();
    if (pedidos.docs.any((d) => d.data()['estado'] != 'entregado') ||
        encargos.docs.isNotEmpty) {
      throw const EliminarCuentaException(MotivoNoEliminar.pedidosEnCurso);
    }

    final lote = _firestore.batch();
    for (final col in [
      'solicitudes_repartidor',
      'solicitudes_empleado',
      'solicitudes_lavanderia',
      'intenciones_pedido',
    ]) {
      final doc = await _firestore.collection(col).doc(uid).get();
      if (doc.exists) lote.delete(doc.reference);
    }
    lote.delete(_firestore.collection('usuarios').doc(uid));
    await lote.commit();
    await user.delete();
  }

  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> enviarCorreoRecuperacion(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// El propio empleado actualiza su bio ("busco trabajo") y salario
  /// esperado, visibles para los admins en la bolsa de disponibles.
  /// Paso obligatorio tras el registro de un cliente: nombres, apellidos y el
  /// punto de recojo de la ropa. No pide identidad ni carnet.
  Future<void> completarPerfilCliente({
    required String uid,
    required String nombres,
    required String apellidos,
    required String direccion,
    required double lat,
    required double lng,
  }) {
    return _firestore.collection('usuarios').doc(uid).update({
      'nombres': nombres,
      'apellidos': apellidos,
      'nombre': '$nombres $apellidos',
      'direccion': direccion,
      'ubicacionLat': lat,
      'ubicacionLng': lng,
    });
  }

  /// Qué está haciendo el empleado ahora (se ve en la ciudad 3D del admin).
  Future<void> cambiarActividad(String uid, String actividad) {
    return _firestore.collection('usuarios').doc(uid).update({
      'actividad': actividad,
      'actividadEn': FieldValue.serverTimestamp(),
    });
  }

  /// "Aquí es mi casa": solo cambia el punto de recojo guardado.
  Future<void> guardarCasa({
    required String uid,
    required String direccion,
    required double lat,
    required double lng,
  }) {
    return _firestore.collection('usuarios').doc(uid).update({
      'direccion': direccion,
      'ubicacionLat': lat,
      'ubicacionLng': lng,
    });
  }

  Future<void> actualizarBioEmpleado(String uid, String bio) {
    return _firestore.collection('usuarios').doc(uid).update({
      'bioEmpleado': bio,
    });
  }

  /// El propio empleado edita su perfil (foto, CV, fecha de nacimiento,
  /// dónde vive) — visible para los admins al revisarlo en la bolsa o al
  /// contratarlo.
  Future<void> actualizarPerfilEmpleado(
    String uid, {
    required String direccion,
    required String telefono,
    DateTime? fechaNacimiento,
    String? fotoBase64,
    String? cvBase64,
    String? cvNombre,
  }) {
    return _firestore.collection('usuarios').doc(uid).update({
      'direccion': direccion,
      'telefono': telefono,
      if (fechaNacimiento != null)
        'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
      if (fotoBase64 != null) 'fotoBase64': fotoBase64,
      if (cvBase64 != null) 'cvBase64': cvBase64,
      if (cvNombre != null) 'cvNombre': cvNombre,
    });
  }

  /// Vuelve a leer el usuario desde Firebase Auth (tras validar el código de
  /// 6 dígitos en el backend) para refrescar `emailVerified`.
  Future<void> recargarSesion() async {
    await _auth.currentUser?.reload();
  }

  Future<void> iniciarSesionConGoogle() async {
    final UserCredential credential;
    if (kIsWeb) {
      credential = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // el usuario canceló
      final googleAuth = await googleUser.authentication;
      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      credential = await _auth.signInWithCredential(oauthCredential);
    }

    final user = credential.user!;
    final doc = await _firestore.collection('usuarios').doc(user.uid).get();
    if (!doc.exists) {
      await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .set(
            AppUser(
              uid: user.uid,
              nombre: user.displayName ?? 'Usuario',
              email: user.email ?? '',
              role: UserRole.cliente,
            ).toMap(),
          );
    }
  }

  Future<void> cerrarSesion() async {
    await _auth.signOut();
    if (!kIsWeb) await GoogleSignIn().signOut();
  }
}
