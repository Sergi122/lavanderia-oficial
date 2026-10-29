import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'ciudad_3d_control.dart';

int _contador = 0;

/// Ciudad 3D del admin (Three.js) en un iframe que ocupa todo el fondo. Los
/// paneles de Flutter flotan encima; donde no hay panel, el mouse llega a la
/// ciudad (arrastrar, girar, zoom, tocar empleados/pedidos).
class Ciudad3DView extends StatefulWidget {
  final Map<String, dynamic> datos;
  final Ciudad3DControl control;
  final void Function(Seleccion3D?)? onSeleccion;
  final VoidCallback? onSinWebGL;
  const Ciudad3DView({
    super.key,
    required this.datos,
    required this.control,
    this.onSeleccion,
    this.onSinWebGL,
  });

  @override
  State<Ciudad3DView> createState() => _Ciudad3DViewState();
}

class _Ciudad3DViewState extends State<Ciudad3DView> {
  late final String _viewType = 'ciudad3d-${_contador++}';
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _oyente;
  bool _listo = false;
  String _ultimoEnviado = '';
  double _progreso = 0;
  Timer? _plazo;

  @override
  void initState() {
    super.initState();
    _iframe = web.HTMLIFrameElement()
      ..src = '/admin3d.html'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
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
      switch (m['tipo']) {
        case 'listo':
          _listo = true;
          _plazo?.cancel();
          _ultimoEnviado = '';
          _enviarDatos();
          if (mounted) setState(() => _progreso = 1);
        case 'progreso':
          if (mounted)
            setState(() => _progreso = (m['valor'] as num).toDouble());
        case 'seleccion':
          final o = m['obj'];
          widget.onSeleccion?.call(
            o is Map ? Seleccion3D('${o['tipo']}', '${o['id']}') : null,
          );
        case 'sinwebgl':
          widget.onSinWebGL?.call();
      }
    }).toJS;
    web.window.addEventListener('message', _oyente!);
    widget.control.conectar(_enviar);
    _plazo = Timer(const Duration(seconds: 45), () {
      if (!_listo) widget.onSinWebGL?.call();
    });
  }

  void _enviar(Map<String, dynamic> m) {
    if (!_listo) return;
    _iframe.contentWindow?.postMessage(jsonEncode(m).toJS, '*'.toJS);
  }

  void _enviarDatos() {
    final s = jsonEncode(widget.datos);
    if (s == _ultimoEnviado) return;
    _ultimoEnviado = s;
    _enviar({'tipo': 'datos', 'datos': widget.datos});
  }

  @override
  void didUpdateWidget(covariant Ciudad3DView old) {
    super.didUpdateWidget(old);
    if (old.control != widget.control) widget.control.conectar(_enviar);
    _enviarDatos();
  }

  @override
  void dispose() {
    _plazo?.cancel();
    widget.control.desconectar();
    if (_oyente != null) web.window.removeEventListener('message', _oyente!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Con un diálogo o menú encima, el iframe no debe quedarse con los clics.
    final enFrente = ModalRoute.of(context)?.isCurrent ?? true;
    _iframe.style.pointerEvents = enFrente ? 'auto' : 'none';
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewType),
        if (_progreso < 1)
          IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 220,
                child: LinearProgressIndicator(
                  value: _progreso == 0 ? null : _progreso,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Los paneles de Flutter que flotan sobre la ciudad necesitan esto: en la web
/// el iframe recibe los clics aunque haya un widget dibujado encima. Pone un
/// div transparente (vista de plataforma posterior, o sea encima del iframe)
/// del tamaño del panel, y el clic vuelve a llegar a Flutter.
class SobreCiudad3D extends StatelessWidget {
  final Widget child;
  const SobreCiudad3D({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: HtmlElementView.fromTagName(
          tagName: 'div',
          isVisible: false,
          onElementCreated: (e) {
            final d = e as web.HTMLElement;
            d.style.width = '100%';
            d.style.height = '100%';
          },
        ),
      ),
      child,
    ],
  );
}
