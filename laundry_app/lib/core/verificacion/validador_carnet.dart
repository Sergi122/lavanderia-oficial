import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ResultadoLecturaCarnet {
  final bool coincide;
  final bool sePudoLeer;
  const ResultadoLecturaCarnet({
    required this.coincide,
    required this.sePudoLeer,
  });
}

String _soloDigitos(String texto) => texto.replaceAll(RegExp(r'[^0-9]'), '');

/// Lee con OCR (Google ML Kit, offline en el celular) el número impreso en
/// la foto del anverso del carnet y lo compara contra el que la persona
/// escribió en el formulario. Si la foto sale borrosa y no se logra leer
/// ningún número, no bloquea (sePudoLeer=false): queda igual que antes,
/// para que lo revise el verificador humano.
Future<ResultadoLecturaCarnet> verificarNumeroCarnet({
  required Uint8List fotoAnverso,
  required String ciEscrito,
}) async {
  final ciDigitos = _soloDigitos(ciEscrito);
  if (ciDigitos.length < 5) {
    return const ResultadoLecturaCarnet(coincide: true, sePudoLeer: false);
  }

  final archivoTemporal = File(
    '${Directory.systemTemp.path}/carnet_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    await archivoTemporal.writeAsBytes(fotoAnverso);
    final resultado = await recognizer.processImage(
      InputImage.fromFilePath(archivoTemporal.path),
    );

    final candidatos = RegExp(r'[0-9][0-9.\s]{3,}[0-9]')
        .allMatches(resultado.text)
        .map((m) => _soloDigitos(m.group(0)!))
        .where((d) => d.length >= 5)
        .toSet();

    if (candidatos.isEmpty) {
      return const ResultadoLecturaCarnet(coincide: true, sePudoLeer: false);
    }
    return ResultadoLecturaCarnet(
      coincide: candidatos.contains(ciDigitos),
      sePudoLeer: true,
    );
  } catch (e) {
    return const ResultadoLecturaCarnet(coincide: true, sePudoLeer: false);
  } finally {
    await recognizer.close();
    if (await archivoTemporal.exists()) await archivoTemporal.delete();
  }
}
