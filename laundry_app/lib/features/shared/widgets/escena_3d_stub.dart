import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'escena_3d_json.dart';
import 'escena_lavanderia.dart';

const _urlEscena = 'https://laundry-app-asustadores.web.app/escena3d.html';

/// En el celular (Android/iOS) la misma ciudad 3D de la web va en un WebView.
/// Sin WebGL, sin internet o fuera del celular (escritorio, tests) se dibuja la escena 2D.
class Escena3DView extends StatefulWidget {
  final EscenaDatos datos;
  final bool explorar;
  final double aspectRatio;
  const Escena3DView({
    super.key,
    required this.datos,
    this.explorar = false,
    this.aspectRatio = 1.8,
  });

  @override
  State<Escena3DView> createState() => _Escena3DViewState();
}

class _Escena3DViewState extends State<Escena3DView> {
  WebViewController? _c;
  Timer? _plazo;
  bool _listo = false;
  bool _fallback = false;

  static bool get _hayWebView =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    if (!_hayWebView) {
      _fallback = true;
      return;
    }
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFCFE6FB))
      ..addJavaScriptChannel('FlutterBridge', onMessageReceived: _alRecibir)
      ..loadRequest(Uri.parse(_urlEscena));
    _plazo = Timer(const Duration(seconds: 15), () {
      if (!_listo && mounted) setState(() => _fallback = true);
    });
  }

  void _alRecibir(JavaScriptMessage m) {
    Map<String, dynamic> d;
    try {
      d = jsonDecode(m.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (d['tipo'] == 'listo') {
      _listo = true;
      _plazo?.cancel();
      _enviarDatos();
      _enviar({'tipo': 'explorar', 'valor': widget.explorar});
    } else if (d['tipo'] == 'sinwebgl' && mounted) {
      setState(() => _fallback = true);
    }
  }

  void _enviar(Map<String, dynamic> m) {
    if (!_listo) return;
    _c?.runJavaScript('window.__recibir(${jsonEncode(jsonEncode(m))})');
  }

  void _enviarDatos() =>
      _enviar({'tipo': 'datos', 'datos': escenaAJson(widget.datos)});

  @override
  void didUpdateWidget(covariant Escena3DView old) {
    super.didUpdateWidget(old);
    if (jsonEncode(escenaAJson(old.datos)) !=
        jsonEncode(escenaAJson(widget.datos)))
      _enviarDatos();
    if (old.explorar != widget.explorar) {
      _enviar({'tipo': 'explorar', 'valor': widget.explorar});
      if (!widget.explorar) _enviar({'tipo': 'reset'});
    }
  }

  @override
  void dispose() {
    _plazo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fallback || _c == null)
      return EscenaLavanderia(
        datos: widget.datos,
        aspectRatio: widget.aspectRatio,
      );
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      // Sin "Explorar" el WebView no recibe toques: la lista de abajo sigue haciendo scroll.
      child: IgnorePointer(
        ignoring: !widget.explorar,
        child: WebViewWidget(
          controller: _c!,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
      ),
    );
  }
}
