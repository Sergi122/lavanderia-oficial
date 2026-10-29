import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/features/legal/textos_legales.dart';

void main() {
  final json =
      jsonDecode(File('assets/legal/legal.json').readAsStringSync())
          as Map<String, dynamic>;

  test('la versión del JSON coincide con kVersionTerminos', () {
    expect(json['version'], kVersionTerminos);
  });

  test('ambos documentos tienen secciones con texto', () {
    final docs = json['documentos'] as Map<String, dynamic>;
    for (final tipo in ['privacidad', 'terminos']) {
      final secciones = docs[tipo]['secciones'] as List<dynamic>;
      expect(secciones, isNotEmpty, reason: tipo);
      for (final s in secciones) {
        final m = s as Map<String, dynamic>;
        expect(
          (m['parrafos'] ?? m['items']) as List<dynamic>,
          isNotEmpty,
          reason: '$tipo › ${m['titulo']}',
        );
      }
    }
  });
}
