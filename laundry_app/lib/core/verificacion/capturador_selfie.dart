import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import 'validador_selfie.dart';

class CapturadorSelfie extends StatefulWidget {
  final PoseSelfie pose;
  final String titulo;
  final ValueChanged<Uint8List?> onCambio;

  const CapturadorSelfie({
    super.key,
    required this.pose,
    required this.titulo,
    required this.onCambio,
  });

  @override
  State<CapturadorSelfie> createState() => _CapturadorSelfieState();
}

class _CapturadorSelfieState extends State<CapturadorSelfie> {
  Uint8List? _bytes;
  bool _validando = false;
  String? _error;

  Future<void> _tomarFoto() async {
    final archivo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 640,
      imageQuality: 60,
    );
    if (archivo == null) return;

    setState(() {
      _validando = true;
      _error = null;
    });

    final resultado = await validarSelfie(archivo.path, widget.pose);
    if (!resultado.valida) {
      setState(() {
        _validando = false;
        _error = resultado.mensaje;
        _bytes = null;
      });
      widget.onCambio(null);
      return;
    }

    final bytes = await archivo.readAsBytes();
    setState(() {
      _validando = false;
      _bytes = bytes;
    });
    widget.onCambio(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _bytes!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.face_outlined, color: AppTheme.primary),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _validando ? null : _tomarFoto,
                icon: _validando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _bytes != null
                            ? Icons.check_circle
                            : Icons.camera_alt_outlined,
                        color: _bytes != null ? Colors.green : null,
                      ),
                label: Text(
                  _validando
                      ? 'Validando...'
                      : _bytes != null
                      ? 'Selfie ${widget.titulo} lista'
                      : 'Tomar selfie ${widget.titulo}',
                ),
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 64),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
