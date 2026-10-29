import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Mismo servidor de Render que la verificación facial (ver verificacion-backend).
const _base = 'https://backend-primera-parte.onrender.com/codigo';

enum ResultadoEnvio { enviado, esperar, yaVerificado, noDisponible }

enum ResultadoCodigo { ok, incorrecto, vencido, demasiadosIntentos, error }

class CodigoCorreoApi {
  Future<String?> _idToken() =>
      FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(null);

  /// Render (plan gratis) duerme el servidor tras 15 min sin uso y tarda ~30 s
  /// en despertar. Lo llamamos al abrir la app para que esté listo cuando
  /// alguien se registre; si falla no importa.
  static Future<void> despertar() async {
    try {
      await http
          .get(Uri.parse(_base.replaceFirst('/codigo', '/')))
          .timeout(const Duration(seconds: 60));
    } catch (_) {}
  }

  /// Pide el envío del código. Si el servidor no responde (dormido, sin
  /// internet, sin servicio de correo) devuelve [ResultadoEnvio.noDisponible]
  /// y la pantalla ofrece reintentar.
  Future<(ResultadoEnvio, int)> enviar() async {
    try {
      final idToken = await _idToken();
      if (idToken == null) return (ResultadoEnvio.noDisponible, 0);
      final r = await http
          .post(
            Uri.parse('$_base/enviar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(const Duration(seconds: 60));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        return (
          d['yaVerificado'] == true
              ? ResultadoEnvio.yaVerificado
              : ResultadoEnvio.enviado,
          0,
        );
      }
      if (r.statusCode == 429) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        return (ResultadoEnvio.esperar, (d['segundos'] as num?)?.toInt() ?? 45);
      }
      return (ResultadoEnvio.noDisponible, 0);
    } catch (_) {
      return (ResultadoEnvio.noDisponible, 0);
    }
  }

  Future<(ResultadoCodigo, int?)> verificar(String codigo) async {
    try {
      final idToken = await _idToken();
      if (idToken == null) return (ResultadoCodigo.error, null);
      final r = await http
          .post(
            Uri.parse('$_base/verificar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken, 'codigo': codigo}),
          )
          .timeout(const Duration(seconds: 40));
      if (r.statusCode == 200) return (ResultadoCodigo.ok, null);
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      return switch (d['error']) {
        'incorrecto' => (
          ResultadoCodigo.incorrecto,
          (d['restantes'] as num?)?.toInt(),
        ),
        'vencido' => (ResultadoCodigo.vencido, null),
        'demasiados_intentos' => (ResultadoCodigo.demasiadosIntentos, null),
        _ => (ResultadoCodigo.error, null),
      };
    } catch (_) {
      return (ResultadoCodigo.error, null);
    }
  }
}
