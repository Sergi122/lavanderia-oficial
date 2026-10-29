import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/features/shared/widgets/escena_lavanderia.dart';

Future<void> _captura(WidgetTester tester, String nombre, EscenaDatos d, {int segundos = 3}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(720, 480));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(child: RepaintBoundary(key: key, child: SizedBox(width: 700, child: EscenaLavanderia(datos: d)))),
    ),
  ));
  await tester.pump(Duration(seconds: segundos));
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1.5);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(Platform.environment['SHOTS_DIR'] ?? '/tmp')..createSync(recursive: true);
    File('${dir.path}/$nombre.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render escenas', (tester) async {
    await _captura(tester, 'cliente_lavando', const EscenaDatos(lavando: 1, ciclo: true, destacarMia: true,
        motos: []), segundos: 2);
    await _captura(tester, 'cliente_moto_ida', const EscenaDatos(colgadas: 0,
        motos: [MotoEscena(RolMoto.llevando, progreso: 0.5)], destacarMia: true));
    await _captura(tester, 'admin', const EscenaDatos(colgadas: 3, lavando: 2, secando: 1, listas: 3,
        motos: [MotoEscena(RolMoto.llevando), MotoEscena(RolMoto.devolviendo)], nombreLavanderia: 'Lavandería Central'), segundos: 4);
  });
}
