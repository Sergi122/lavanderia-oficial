import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Proporción de una tarjeta ID-1 (carnet), 85.6 x 54 mm.
const double _proporcionCarnet = 85.6 / 54;

/// Pantalla completa con cámara trasera y un marco con forma de carnet:
/// lo de afuera se oscurece y al tomar la foto se recorta SOLO lo que queda
/// dentro del marco (como las apps de banca/KYC). Devuelve los bytes JPEG
/// del recorte, o null si la persona cancela.
class CapturadorCarnet extends StatefulWidget {
  final String titulo;
  const CapturadorCarnet({super.key, required this.titulo});

  static Future<Uint8List?> abrir(
    BuildContext context, {
    required String titulo,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CapturadorCarnet(titulo: titulo),
      ),
    );
  }

  @override
  State<CapturadorCarnet> createState() => _CapturadorCarnetState();
}

class _CapturadorCarnetState extends State<CapturadorCarnet> {
  CameraController? _controller;
  bool _procesando = false;
  String? _error;

  // Marco como fracción del ancho de la vista previa.
  static const double _anchoMarco = 0.9;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final camaras = await availableCameras();
      final trasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      final c = CameraController(
        trasera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir la cámara.');
    }
  }

  Future<void> _tomar() async {
    final c = _controller;
    if (c == null || _procesando) return;
    setState(() => _procesando = true);
    try {
      final foto = await c.takePicture();
      final bytes = await foto.readAsBytes();
      final recorte = _recortar(bytes);
      // Liberar la cámara ANTES de salir: el plugin hace unbindAll() al
      // cerrar y, si eso pasa después de que arranca la cámara frontal de
      // la selfie, la deja desconectada (pantalla vacía, sin frames).
      if (mounted) setState(() => _controller = null);
      await c.dispose();
      if (mounted) Navigator.of(context).pop(recorte);
    } catch (e) {
      if (mounted) {
        setState(() {
          _procesando = false;
          _error = 'No se pudo tomar la foto, intenta de nuevo.';
        });
      }
    }
  }

  Uint8List _recortar(Uint8List jpeg) {
    final original = img.decodeImage(jpeg);
    if (original == null) return jpeg;
    final foto = img.bakeOrientation(original);

    final w = foto.width.toDouble();
    final h = foto.height.toDouble();
    // Mismo cálculo que el marco en pantalla, en coordenadas de la foto.
    var cw = w * _anchoMarco;
    var ch = cw / _proporcionCarnet;
    if (ch > h) {
      ch = h;
      cw = ch * _proporcionCarnet;
    }
    final x = ((w - cw) / 2).round();
    final y = ((h - ch) / 2).round();

    var recorte = img.copyCrop(
      foto,
      x: x,
      y: y,
      width: cw.round(),
      height: ch.round(),
    );
    // Mismo tamaño/calidad que antes: cada imagen va en base64 dentro del
    // documento de Firestore (límite 1MB).
    if (recorte.width > 700) recorte = img.copyResize(recorte, width: 700);
    return Uint8List.fromList(img.encodeJpg(recorte, quality: 55));
  }

  @override
  void dispose() {
    // Si ya se liberó en _tomar, _controller es null.
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.titulo),
      ),
      body: SafeArea(
        child: c == null || !c.value.isInitialized
            ? Center(
                child: _error != null
                    ? Text(_error!, style: const TextStyle(color: Colors.white))
                    : const CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1 / c.value.aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(c),
                            const CustomPaint(painter: _MarcoPainter()),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      'Coloca el carnet dentro del marco, con buena luz y sin reflejos',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 8),
                    child: _procesando
                        ? const SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : GestureDetector(
                            onTap: _tomar,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.white54,
                                  width: 5,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MarcoPainter extends CustomPainter {
  const _MarcoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    var mw = size.width * _CapturadorCarnetState._anchoMarco;
    var mh = mw / _proporcionCarnet;
    if (mh > size.height) {
      mh = size.height;
      mw = mh * _proporcionCarnet;
    }
    final marco = RRect.fromRectAndRadius(
      Rect.fromCenter(center: size.center(Offset.zero), width: mw, height: mh),
      const Radius.circular(14),
    );

    final oscuro = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(marco);
    canvas.drawPath(
      oscuro,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    canvas.drawRRect(
      marco,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Esquinas resaltadas.
    final esquina = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final r = marco.outerRect;
    final l = math.min(mw, mh) * 0.18;
    for (final (p, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(p, p + Offset(dx * l, 0), esquina);
      canvas.drawLine(p, p + Offset(0, dy * l), esquina);
    }
  }

  @override
  bool shouldRepaint(covariant _MarcoPainter oldDelegate) => false;
}
