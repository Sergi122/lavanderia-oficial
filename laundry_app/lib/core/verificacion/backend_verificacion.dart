import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Desplegado en Render — ver ~/lavanderia-app/verificacion-backend/README.md
const urlBackendVerificacion =
    'https://backend-primera-parte.onrender.com/verificar';

class ResultadoVerificacionBackend {
  final bool aprobado;
  final String motivo;
  final bool sePudoContactar;
  const ResultadoVerificacionBackend({
    required this.aprobado,
    required this.motivo,
    required this.sePudoContactar,
  });
}

/// Espera la respuesta del backend de verificación automática (compara la
/// selfie contra el carnet con IA) antes de dejar avanzar al usuario. El
/// plan gratis de Render "duerme" el servidor tras un rato sin uso, así que
/// la primera llamada del día puede tardar hasta ~50s en despertar — por
/// eso el timeout es largo y el mensaje de espera lo avisa.
///
/// Si el backend no está disponible (caído, no configurado, sin internet),
/// no bloquea: el verificador humano sigue pudiendo aprobar a mano.
Future<ResultadoVerificacionBackend> verificarSolicitudBloqueante({
  required String tipo,
  required String uid,
}) async {
  if (urlBackendVerificacion.isEmpty) {
    return const ResultadoVerificacionBackend(
      aprobado: false,
      motivo: 'Verificación automática no configurada.',
      sePudoContactar: false,
    );
  }

  try {
    // El servidor comprueba la sesión del propio postulante (no hay secreto
    // dentro de la app: se podía sacar del APK o de la web).
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      return const ResultadoVerificacionBackend(
        aprobado: false,
        motivo: 'Sin sesión iniciada.',
        sePudoContactar: false,
      );
    }
    final respuesta = await http
        .post(
          Uri.parse(urlBackendVerificacion),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'tipo': tipo, 'uid': uid}),
        )
        .timeout(const Duration(seconds: 75));

    if (respuesta.statusCode != 200) {
      return ResultadoVerificacionBackend(
        aprobado: false,
        motivo:
            'El servidor de verificación respondió con un error (${respuesta.statusCode}).',
        sePudoContactar: true,
      );
    }

    final data = jsonDecode(respuesta.body) as Map<String, dynamic>;
    return ResultadoVerificacionBackend(
      aprobado: data['aprobado'] == true,
      motivo: data['motivo'] as String? ?? '',
      sePudoContactar: true,
    );
  } catch (e) {
    debugPrint(
      'No se pudo contactar al backend de verificación automática: $e',
    );
    return const ResultadoVerificacionBackend(
      aprobado: false,
      motivo: 'No se pudo contactar al servidor de verificación.',
      sePudoContactar: false,
    );
  }
}
