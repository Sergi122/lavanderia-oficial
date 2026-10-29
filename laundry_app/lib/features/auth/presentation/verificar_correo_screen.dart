import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/abanico_cartas.dart';
import '../data/auth_repository.dart';
import '../data/codigo_correo_api.dart';

const _largo = 6;

/// Verificación del correo con código de 6 dígitos (cartas en abanico). Solo
/// código: no hay enlace de Firebase. Si el servidor no puede mandarlo se
/// reintenta una vez sola (puede estar despertando) y luego a mano.
class VerificarCorreoScreen extends ConsumerStatefulWidget {
  const VerificarCorreoScreen({super.key});

  @override
  ConsumerState<VerificarCorreoScreen> createState() =>
      _VerificarCorreoScreenState();
}

class _VerificarCorreoScreenState extends ConsumerState<VerificarCorreoScreen> {
  final _api = CodigoCorreoApi();
  final _ctrl = TextEditingController();
  final _foco = FocusNode();

  bool _enviando = true;
  bool _fallo = false; // el servidor no pudo mandar el código
  bool _reintentado = false;
  bool _verificando = false;
  bool _exito = false;
  int _errores = 0; // cambia la key para repetir el temblor
  bool _error = false;
  String? _mensaje;
  int _espera = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_alCambiar);
    WidgetsBinding.instance.addPostFrameCallback((_) => _enviarCodigo());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _iniciarEspera(int segundos) {
    _timer?.cancel();
    setState(() => _espera = segundos);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _espera = (_espera - 1).clamp(0, 999));
      if (_espera == 0) t.cancel();
    });
  }

  Future<void> _enviarCodigo() async {
    setState(() {
      _enviando = true;
      _fallo = false;
      _mensaje = null;
    });
    var (res, seg) = await _api.enviar();
    if (res == ResultadoEnvio.noDisponible && !_reintentado && mounted) {
      _reintentado = true; // primera vez del día: Render recién despertó
      (res, seg) = await _api.enviar();
    }
    if (!mounted) return;
    switch (res) {
      case ResultadoEnvio.enviado:
        setState(() {
          _enviando = false;
          _mensaje = 'Te enviamos un código de 6 dígitos.';
        });
        _iniciarEspera(45);
        _foco.requestFocus();
      case ResultadoEnvio.esperar:
        setState(() {
          _enviando = false;
          _mensaje = 'Ya te enviamos un código hace poco. Revisa tu correo.';
        });
        _iniciarEspera(seg);
        _foco.requestFocus();
      case ResultadoEnvio.yaVerificado:
        await _refrescarSesion();
      case ResultadoEnvio.noDisponible:
        setState(() {
          _fallo = true;
          _enviando = false;
        });
    }
  }

  void _abrirTeclado() {
    if (_foco.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _foco.requestFocus();
    }
  }

  void _alCambiar() {
    setState(() => _error = false);
    if (_ctrl.text.length == _largo && !_verificando && !_exito) _verificar();
  }

  Future<void> _verificar() async {
    setState(() {
      _verificando = true;
      _mensaje = null;
    });
    final (res, restantes) = await _api.verificar(_ctrl.text);
    if (!mounted) return;
    if (res == ResultadoCodigo.ok) {
      setState(() {
        _exito = true;
        _verificando = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await _refrescarSesion();
      return;
    }
    setState(() {
      _verificando = false;
      _error = true;
      _errores++;
      _mensaje = switch (res) {
        ResultadoCodigo.incorrecto =>
          'Código incorrecto${restantes != null ? ' · te quedan $restantes intento${restantes == 1 ? '' : 's'}' : ''}.',
        ResultadoCodigo.vencido => 'El código venció. Pide uno nuevo.',
        ResultadoCodigo.demasiadosIntentos =>
          'Demasiados intentos. Pide un código nuevo.',
        _ => 'No pudimos verificar el código. Intenta de nuevo.',
      };
    });
    _ctrl.clear();
    _foco.requestFocus();
  }

  Future<void> _refrescarSesion() async {
    await ref.read(authRepositoryProvider).recargarSesion();
    ref.invalidate(authStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final email =
        ref.watch(authStateProvider).valueOrNull?.email ?? 'tu correo';
    final texto = _ctrl.text;

    final cartas = [
      for (var i = 0; i < _largo; i++)
        CartaAbanico(
          texto: i < texto.length ? texto[i] : '',
          estado: _exito
              ? EstadoCarta.ok
              : _error
              ? EstadoCarta.error
              : i < texto.length
              ? EstadoCarta.llena
              : (i == texto.length ? EstadoCarta.activa : EstadoCarta.vacia),
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF070F1F),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2F7FE0).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 40,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: _enviando
                      ? const _Enviando()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fallo
                                  ? 'No pudimos enviar el código'
                                  : 'Ingresa tu código',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _fallo
                                  ? 'Revisa tu conexión a internet e inténtalo de nuevo. El código irá a $email'
                                  : 'Enviamos un código de 6 dígitos a $email. Si no lo ves, revisa la carpeta de spam.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white60,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (!_fallo) ...[
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  AbanicoCartas(
                                        key: ValueKey(_errores),
                                        cartas: cartas,
                                        onTap: _abrirTeclado,
                                      )
                                      .animate(
                                        key: ValueKey('t$_errores'),
                                        target: _error ? 1 : 0,
                                      )
                                      .shakeX(
                                        hz: 5,
                                        amount: 6,
                                        duration: 420.ms,
                                      ),
                                  // Campo real, transparente y del tamaño de las
                                  // cartas: cualquier toque abre el teclado (con
                                  // 1×1 px no se reabría si ya tenía el foco), y
                                  // mantener pulsado permite pegar.
                                  Positioned.fill(
                                    child: TextField(
                                      controller: _ctrl,
                                      focusNode: _foco,
                                      autofocus: true,
                                      keyboardType: TextInputType.number,
                                      autofillHints: const [
                                        AutofillHints.oneTimeCode,
                                      ],
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(
                                          _largo,
                                        ),
                                      ],
                                      showCursor: false,
                                      expands: true,
                                      maxLines: null,
                                      style: const TextStyle(
                                        color: Colors.transparent,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        filled: false,
                                        counterText: '',
                                      ),
                                      onTap: _abrirTeclado,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              AnimatedSwitcher(
                                duration: 250.ms,
                                child: _verificando
                                    ? const SizedBox(
                                        key: ValueKey('v'),
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF8FD7FF),
                                        ),
                                      )
                                    : Text(
                                        _exito
                                            ? '¡Correo verificado!'
                                            : (_mensaje ??
                                                  'Escribe o pega el código'),
                                        key: ValueKey(_mensaje ?? _exito),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _exito
                                              ? const Color(0xFF3DDC84)
                                              : _error
                                              ? const Color(0xFFFF8A8A)
                                              : Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: _espera > 0 || _verificando
                                    ? null
                                    : _enviarCodigo,
                                child: Text(
                                  _espera > 0
                                      ? 'Reenviar código en ${_espera}s'
                                      : 'Reenviar código',
                                ),
                              ),
                            ] else
                              FilledButton.icon(
                                onPressed: _enviarCodigo,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Enviar código de nuevo'),
                              ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () => ref
                                  .read(authRepositoryProvider)
                                  .cerrarSesion(),
                              child: const Text(
                                'Cerrar sesión',
                                style: TextStyle(color: Colors.white38),
                              ),
                            ),
                          ],
                        ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Enviando extends StatelessWidget {
  const _Enviando();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimacionVerificacionFoto(
            mensaje: 'Enviando tu código… (puede tardar hasta un minuto)',
            iconos: [
              Icons.mail_outline,
              Icons.lock_outline,
              Icons.sms_outlined,
              Icons.verified_outlined,
            ],
            ayuda: null,
          ),
        ],
      ),
    );
  }
}
