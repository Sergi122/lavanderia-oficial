import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/features/admin/presentation/finanzas_widgets.dart';
import 'package:laundry_app/features/auth/presentation/hero_demo.dart';

Future<void> _shot(WidgetTester tester, String nombre, Widget w, Size size, {int ms = 1500}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: const Color(0xFFF1F7FD),
      body: RepaintBoundary(key: key, child: w),
    ),
  ));
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(Duration(milliseconds: ms ~/ 6));
  }
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1.5);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(Platform.environment['SHOTS_DIR'] ?? '/tmp')..createSync(recursive: true);
    File('${dir.path}/$nombre.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('finanzas', (tester) async {
    final serie = [
      for (var i = 1; i <= 14; i++) PuntoSerie('$i', i % 3 == 0 ? 0 : 80.0 * (1 + (i * 7) % 5), 40.0 + (i % 4) * 25),
    ];
    await _shot(
      tester,
      'finanzas',
      ListView(padding: const EdgeInsets.all(16), children: [
        const TarjetaBalance(balance: 3240, ingresos: 5100, egresos: 1860, variacion: 18, periodo: 'Este mes'),
        const SizedBox(height: 12),
        const FilaIndicadores(items: [
          ('Pedidos cobrados', '42', Icons.receipt_long_outlined),
          ('Ticket promedio', 'Bs 121', Icons.shopping_bag_outlined),
          ('Por cobrar', 'Bs 460', Icons.hourglass_bottom_rounded),
        ]),
        const SizedBox(height: 16),
        BloqueFinanzas(titulo: 'Ingresos vs. egresos', subtitulo: 'Toca una barra', child: GraficoIngresosEgresos(puntos: serie)),
        const SizedBox(height: 16),
        const BloqueFinanzas(
          titulo: 'En qué se va el dinero',
          child: DesgloseGastos(filas: [
            ('Planilla', 1200, Icons.groups_outlined),
            ('Electricidad', 380, Icons.bolt_outlined),
            ('Detergente / jabón', 280, Icons.soap_outlined),
          ]),
        ),
      ]),
      const Size(420, 1100),
    );
  });

  testWidgets('hero', (tester) async {
    await _shot(
        tester,
        'hero',
        const Padding(padding: EdgeInsets.all(24), child: Center(child: SizedBox(width: 560, child: HeroDemo()))),
        const Size(620, 900),
        ms: 2500);
  });
}
