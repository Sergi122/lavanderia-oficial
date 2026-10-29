import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Versión vigente de la política y los términos. Si cambia, el router vuelve
/// a pedir la aceptación a todos (ver `AceptarTerminosScreen`). Debe coincidir
/// con `version` de assets/legal/legal.json.
const kVersionTerminos = '2026-10-26';

/// Mismo texto publicado en la web (landing/public/privacidad.html y
/// terminos.html, generados desde el JSON con tool/gen_legal_html.py).
const kUrlPrivacidad = 'https://laundry-app-asustadores.web.app/privacidad';
const kUrlTerminos = 'https://laundry-app-asustadores.web.app/terminos';

class SeccionLegal {
  final String titulo;
  final List<String> parrafos;
  final List<String> items;

  const SeccionLegal(this.titulo, this.parrafos, this.items);
}

class DocumentoLegal {
  final String titulo;
  final String intro;
  final String actualizado;
  final List<SeccionLegal> secciones;

  const DocumentoLegal(
    this.titulo,
    this.intro,
    this.actualizado,
    this.secciones,
  );
}

List<String> _lista(Object? v) =>
    (v as List<dynamic>? ?? const []).cast<String>();

/// 'privacidad' | 'terminos'
final documentoLegalProvider = FutureProvider.family<DocumentoLegal, String>((
  ref,
  tipo,
) async {
  final json = jsonDecode(
    await rootBundle.loadString('assets/legal/legal.json'),
  ) as Map<String, dynamic>;
  final d =
      (json['documentos'] as Map<String, dynamic>)[tipo]
          as Map<String, dynamic>;
  return DocumentoLegal(
    d['titulo'] as String,
    d['intro'] as String,
    json['actualizado'] as String,
    [
      for (final s in d['secciones'] as List<dynamic>)
        SeccionLegal(
          (s as Map<String, dynamic>)['titulo'] as String,
          _lista(s['parrafos']),
          _lista(s['items']),
        ),
    ],
  );
});
