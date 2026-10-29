import 'dart:math' as math;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../legal/legal_screens.dart';
import '../../legal/textos_legales.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  bool _esRegistro = false;
  bool _aceptaTerminos = false;
  bool _cargando = false;
  bool _verContrasena = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_esRegistro && !_aceptaTerminos) {
      setState(
        () => _error = 'Para crear tu cuenta debes aceptar la política de privacidad y los términos.',
      );
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });

    final repo = ref.read(authRepositoryProvider);
    try {
      if (_esRegistro) {
        await repo.registrar(
          nombre: _nombreCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          telefono: _telefonoCtrl.text.trim(),
          versionTerminos: kVersionTerminos,
        );
      } else {
        await repo.iniciarSesion(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mensajeError(e.code));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _recuperarContrasena() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Tu correo electrónico'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(emailCtrl.text.trim()),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await ref.read(authRepositoryProvider).enviarCorreoRecuperacion(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Te enviamos un enlace para recuperar tu contraseña a $email',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_mensajeError(e.code))));
      }
    }
  }

  Future<void> _continuarConGoogle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).iniciarSesionConGoogle();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mensajeError(e.code));
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión con Google.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _mensajeError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ese correo ya está registrado.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'El correo no es válido.';
      default:
        return 'Ocurrió un error. Intenta de nuevo.';
    }
  }

  static const _agua = Color(0xFF8FD7FF);
  static const _azul = Color(0xFF3D8EEB);

  InputDecoration _deco(String label, IconData icono, {Widget? sufijo}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icono, size: 20),
      suffixIcon: sufijo,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.10),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
      floatingLabelStyle: const TextStyle(color: _agua),
      prefixIconColor: Colors.white70,
      suffixIconColor: Colors.white70,
      errorStyle: const TextStyle(color: Color(0xFFFFB4B4)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _agua, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFFB4B4)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFFB4B4), width: 1.6),
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final fuente = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _esRegistro ? 'Crear cuenta' : 'Bienvenido de nuevo',
            style: fuente.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _esRegistro
                ? 'Regístrate para gestionar tus pedidos'
                : 'Inicia sesión para continuar',
            style: fuente.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 26),
          if (_esRegistro) ...[
            TextFormField(
              controller: _nombreCtrl,
              style: const TextStyle(color: Colors.white),
              cursorColor: _agua,
              decoration: _deco('Nombre completo', Icons.person_outline),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            cursorColor: _agua,
            decoration: _deco('Correo electrónico', Icons.mail_outline),
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Ingresa un correo válido'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: !_verContrasena,
            style: const TextStyle(color: Colors.white),
            cursorColor: _agua,
            decoration: _deco(
              'Contraseña',
              Icons.lock_outline,
              sufijo: IconButton(
                tooltip: _verContrasena
                    ? 'Ocultar contraseña'
                    : 'Ver contraseña',
                icon: Icon(
                  _verContrasena
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _verContrasena = !_verContrasena),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
          ),
          if (!_esRegistro)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _cargando ? null : _recuperarContrasena,
                style: TextButton.styleFrom(foregroundColor: _agua),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
          if (_esRegistro) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              cursorColor: _agua,
              decoration: _deco('Celular (opcional)', Icons.phone_outlined),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _aceptaTerminos,
                  side: const BorderSide(color: Colors.white54),
                  activeColor: _agua,
                  checkColor: const Color(0xFF06213F),
                  onChanged: (v) =>
                      setState(() => _aceptaTerminos = v ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: TextoAceptoTerminos(),
                  ),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFB4B4).withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFFD6D6), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 22),
          BotonVidrio(
            onPressed: _cargando ? null : _enviar,
            child: _cargando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF06213F),
                    ),
                  )
                : Text(_esRegistro ? 'Registrarme' : 'Iniciar sesión'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.2)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('o', style: TextStyle(color: Colors.white54)),
              ),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _cargando ? null : _continuarConGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
            label: const Text('Continuar con Google'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _cargando
                ? null
                : () => setState(() {
                    _esRegistro = !_esRegistro;
                    _error = null;
                  }),
            style: TextButton.styleFrom(foregroundColor: _agua),
            child: Text(
              _esRegistro
                  ? '¿Ya tienes cuenta? Inicia sesión'
                  : '¿No tienes cuenta? Regístrate',
            ),
          ),
        ],
      ),
    );
  }

  Widget _marca(BuildContext context, {required bool centrada}) {
    final fuente = Theme.of(context).textTheme;
    final alin = centrada
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alin,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.4, -0.45),
                  colors: [Colors.white, _agua, _azul],
                  stops: [0, 0.45, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _agua.withValues(alpha: 0.6),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_laundry_service_rounded,
                color: Color(0xFF06213F),
                size: 30,
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(begin: const Offset(0.6, 0.6)),
        const SizedBox(height: 18),
        Text(
              'Unión de\nLavanderías',
              textAlign: centrada ? TextAlign.center : TextAlign.left,
              style: fuente.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.05,
                letterSpacing: -1,
              ),
            )
            .animate()
            .fadeIn(delay: 120.ms, duration: 500.ms)
            .moveY(begin: 14, end: 0),
        const SizedBox(height: 10),
        Text(
          'Tu ropa, en las mejores manos de La Paz.',
          textAlign: centrada ? TextAlign.center : TextAlign.left,
          style: fuente.titleMedium?.copyWith(color: Colors.white70),
        ).animate().fadeIn(delay: 220.ms, duration: 500.ms),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1C33),
      body: Stack(
        children: [
          const Positioned.fill(child: FondoAgua()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final ancho = c.maxWidth >= 900;
                final tarjeta =
                    ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                28,
                                30,
                                28,
                                20,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.20),
                                    Colors.white.withValues(alpha: 0.06),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _agua.withValues(alpha: 0.15),
                                    blurRadius: 40,
                                  ),
                                  const BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 50,
                                    offset: Offset(0, 24),
                                  ),
                                ],
                              ),
                              child: _formulario(context),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 150.ms, duration: 600.ms)
                        .moveY(begin: 24, end: 0);

                final contenido = ancho
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: _marca(context, centrada: false),
                            ),
                          ),
                          const SizedBox(width: 80),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: tarjeta,
                          ),
                        ],
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _marca(context, centrada: true),
                            const SizedBox(height: 28),
                            tarjeta,
                          ],
                        ),
                      );

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: contenido,
                  ),
                );
              },
            ),
          ),
          if (kIsWeb)
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: TextButton.icon(
                  onPressed: () =>
                      launchUrl(Uri.parse('/'), webOnlyWindowName: '_self'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Volver al inicio'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botón principal estilo vidrio claro (igual que en la landing).
class BotonVidrio extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const BotonVidrio({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.7 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFCFEAFF), Color(0xFF8FD7FF)],
            stops: [0, 0.5, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3D8EEB).withValues(alpha: 0.6),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  color: Color(0xFF06213F),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fondo azul agua con degradado y burbujas que suben lentamente.
class FondoAgua extends StatefulWidget {
  const FondoAgua();

  @override
  State<FondoAgua> createState() => _FondoAguaState();
}

class _FondoAguaState extends State<FondoAgua>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.2),
          radius: 1.5,
          colors: [Color(0xFF1F5794), Color(0xFF0D2A4A), Color(0xFF071829)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => CustomPaint(painter: _PintorBurbujas(_ctrl.value)),
        ),
      ),
    );
  }
}

class _PintorBurbujas extends CustomPainter {
  final double t;
  _PintorBurbujas(this.t);

  // (x 0..1, radio, velocidad, fase)
  static const _b = [
    (0.06, 22.0, 1.0, 0.00),
    (0.17, 9.0, 2.0, 0.35),
    (0.29, 34.0, 1.0, 0.60),
    (0.44, 12.0, 2.0, 0.15),
    (0.58, 26.0, 1.0, 0.80),
    (0.71, 10.0, 2.0, 0.50),
    (0.83, 40.0, 1.0, 0.25),
    (0.93, 17.0, 2.0, 0.70),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in _b) {
      final prog = ((t * b.$3) + b.$4) % 1.0;
      final y = size.height + b.$2 - prog * (size.height + b.$2 * 2);
      final x =
          b.$1 * size.width + math.sin(prog * math.pi * 2 + b.$4 * 6) * 18;
      final c = Offset(x, y);
      final r = b.$2;
      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.45),
          colors: [
            Colors.white.withValues(alpha: 0.7),
            const Color(0xFF8FD7FF).withValues(alpha: 0.16),
            const Color(0xFF8FD7FF).withValues(alpha: 0.04),
          ],
          stops: const [0, 0.4, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white.withValues(alpha: 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorBurbujas old) => old.t != t;
}
