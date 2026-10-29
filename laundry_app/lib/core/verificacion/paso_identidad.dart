import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/auth/data/auth_repository.dart';

/// Datos comunes a cualquiera que quiera trabajar (empleado o dueño de
/// lavandería): quién es, su carnet y una selfie.
class VerificacionIdentidad {
  final String nombre;
  final String ci;
  final String telefono;
  final Uint8List carnetAnverso;
  final Uint8List carnetReverso;
  final Uint8List selfieFrente;
  final Uint8List selfieLado;

  const VerificacionIdentidad({
    required this.nombre,
    required this.ci,
    required this.telefono,
    required this.carnetAnverso,
    required this.carnetReverso,
    required this.selfieFrente,
    required this.selfieLado,
  });
}

extension VerificacionIdentidadDisplay on VerificacionIdentidad {
  String get nombreParaMostrar => nombre.isEmpty ? 'listo' : nombre;
}

/// Versión simple del paso de identidad: pide los datos y las fotos (carnet y
/// selfie). La selfie en vivo y la comparación facial son del módulo de
/// Verificación, que todavía no forma parte de esta primera parte.
class PasoVerificacionIdentidad extends ConsumerStatefulWidget {
  final ValueChanged<VerificacionIdentidad> onVerificado;

  const PasoVerificacionIdentidad({super.key, required this.onVerificado});

  @override
  ConsumerState<PasoVerificacionIdentidad> createState() =>
      _PasoVerificacionIdentidadState();
}

class _PasoVerificacionIdentidadState
    extends ConsumerState<PasoVerificacionIdentidad> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  final _ciCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  Uint8List? _anverso;
  Uint8List? _reverso;
  Uint8List? _selfie;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
      text: ref.read(currentAppUserProvider).valueOrNull?.nombre ?? '',
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ciCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<Uint8List?> _elegirFoto() async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
    return foto?.readAsBytes();
  }

  void _continuar() {
    if (!_formKey.currentState!.validate()) return;
    if (_anverso == null || _reverso == null || _selfie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sube las dos caras del carnet y tu selfie.'),
        ),
      );
      return;
    }
    widget.onVerificado(
      VerificacionIdentidad(
        nombre: _nombreCtrl.text.trim(),
        ci: _ciCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        carnetAnverso: _anverso!,
        carnetReverso: _reverso!,
        selfieFrente: _selfie!,
        selfieLado: _selfie!,
      ),
    );
  }

  Widget _foto(String etiqueta, Uint8List? bytes, ValueChanged<Uint8List> ok) {
    return ListTile(
      leading: bytes == null
          ? const Icon(Icons.add_a_photo_outlined)
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                bytes,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
      title: Text(etiqueta),
      subtitle: Text(bytes == null ? 'Toca para subir la foto' : 'Lista'),
      onTap: () async {
        final b = await _elegirFoto();
        if (b != null) setState(() => ok(b));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String? requerido(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Obligatorio' : null;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Antes de trabajar con nosotros, confirma quién eres.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.construction_rounded),
              title: Text('Estamos trabajando en la verificación con cámara.'),
              subtitle: Text(
                'La selfie en vivo y la comparación con el carnet llegan con '
                'el módulo de Verificación. Por ahora sube las fotos.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
            validator: requerido,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ciCtrl,
            decoration: const InputDecoration(labelText: 'Carnet de identidad'),
            validator: requerido,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telefonoCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono'),
            validator: requerido,
          ),
          const SizedBox(height: 12),
          _foto('Carnet (anverso)', _anverso, (b) => _anverso = b),
          _foto('Carnet (reverso)', _reverso, (b) => _reverso = b),
          _foto('Selfie', _selfie, (b) => _selfie = b),
          const SizedBox(height: 20),
          FilledButton(onPressed: _continuar, child: const Text('Continuar')),
        ],
      ),
    );
  }
}
