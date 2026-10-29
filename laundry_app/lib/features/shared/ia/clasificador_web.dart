import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'clasificador_tipos.dart';

bool get clasificadorDisponible => true;

@JS('clasificarPrenda')
external JSPromise<JSArray<JSNumber>> _clasificarJs(JSString base64);

List<String>? _etiquetas;
Future<void>? _cargando;

/// Carga tfjs + tfjs-tflite y web/ia/clasificador_prendas.js solo cuando se
/// usa (no frena el arranque de la app).
Future<void> _cargar() => _cargando ??= () async {
  Future<void> script(String src) {
    final listo = web.document.createElement('script') as web.HTMLScriptElement;
    listo.src = src;
    final c = listo.onLoad.first;
    web.document.head!.append(listo);
    return c.then((_) {});
  }

  await script('ia/clasificador_prendas.js');
  final r = await web.window.fetch('assets/$rutaEtiquetasPrendas'.toJS).toDart;
  final texto = (await r.text().toDart).toDart;
  _etiquetas = const LineSplitter()
      .convert(texto)
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}();

Future<List<PrediccionPrenda>> clasificarPrenda(Uint8List imagen) async {
  await _cargar();
  final probs = await _clasificarJs(base64Encode(imagen).toJS).toDart;
  return ordenarPredicciones(_etiquetas!, [
    for (final p in probs.toDart) p.toDartDouble,
  ]);
}
