import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'escena_3d_json.dart';
import 'escena_lavanderia.dart';

int _contador = 0;

/// Ciudad 3D de la landing (Three.js) dentro de un iframe. Si la página 3D no
/// carga en 8 s o el navegador no tiene WebGL, cae a la escena 2D.
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
  late final String _viewType = 'escena3d-${_contador++}';
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _oyente;
  Timer? _plazo;
  bool _listo = false;
  bool _fallback = false;

  @override
  void initState() {
    super.initState();
    _iframe = web.HTMLIFrameElement()
      ..src = '/escena3d.html'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.pointerEvents = 'none';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _iframe,
    );
    _oyente = ((web.MessageEvent e) {
      final d = e.data;
      if (!d.isA<JSString>()) return;
      Map<String, dynamic> m;
      try {
        m = jsonDecode((d as JSString).toDart) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
      if (m['tipo'] == 'listo') {
        _listo = true;
        _plazo?.cancel();
        _enviarDatos();
        _enviar({'tipo': 'explorar', 'valor': widget.explorar});
      } else if (m['tipo'] == 'sinwebgl' && mounted) {
        setState(() => _fallback = true);
      }
    }).toJS;
    web.window.addEventListener('message', _oyente!);
    _plazo = Timer(const Duration(seconds: 8), () {
      if (!_listo && mounted) setState(() => _fallback = true);
    });
  }

  void _enviar(Map<String, dynamic> m) {
    if (!_listo) return;
    _iframe.contentWindow?.postMessage(jsonEncode(m).toJS, '*'.toJS);
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
      _iframe.style.pointerEvents = widget.explorar ? 'auto' : 'none';
      _enviar({'tipo': 'explorar', 'valor': widget.explorar});
      if (!widget.explorar) _enviar({'tipo': 'reset'});
    }
  }

  @override
  void dispose() {
    _plazo?.cancel();
    if (_oyente != null) web.window.removeEventListener('message', _oyente!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fallback)
      return EscenaLavanderia(
        datos: widget.datos,
        aspectRatio: widget.aspectRatio,
      );
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
