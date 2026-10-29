import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/core/widgets/abanico_cartas.dart';

void main() {
  testWidgets('abanico estados', (tester) async {
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(440, 640));
    List<CartaAbanico> c(String t, EstadoCarta Function(int) f) =>
        [for (var i = 0; i < 6; i++) CartaAbanico(texto: i < t.length ? t[i] : '', estado: f(i))];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF070F1F),
        body: RepaintBoundary(
          key: key,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              AbanicoCartas(cartas: c('482', (i) => i < 3 ? EstadoCarta.llena : i == 3 ? EstadoCarta.activa : EstadoCarta.vacia)),
              AbanicoCartas(cartas: c('', (i) => EstadoCarta.ok)),
              AbanicoCartas(cartas: c('481927', (i) => EstadoCarta.error)),
              const SizedBox(height: 12),
              const AnimacionVerificacionFoto(),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${Platform.environment['SHOTS_DIR'] ?? '/tmp'}/abanico.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
