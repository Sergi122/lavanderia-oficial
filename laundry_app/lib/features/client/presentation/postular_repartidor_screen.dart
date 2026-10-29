import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/verificacion/paso_identidad.dart';
import '../data/postulacion_repartidor_repository.dart';

class PostularRepartidorScreen extends ConsumerStatefulWidget {
  final VerificacionIdentidad? identidadInicial;

  const PostularRepartidorScreen({super.key, this.identidadInicial});

  @override
  ConsumerState<PostularRepartidorScreen> createState() =>
      _PostularRepartidorScreenState();
}

class _PostularRepartidorScreenState
    extends ConsumerState<PostularRepartidorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placaCtrl = TextEditingController();
  XFile? _matriculaMoto;
  XFile? _licenciaConducir;
  bool _enviando = false;

  late VerificacionIdentidad? _identidad = widget.identidadInicial;

  @override
  void dispose() {
    _placaCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto(void Function(XFile) asignar) async {
    final resultado = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 700,
      imageQuality: 55,
    );
    if (resultado == null) return;
    setState(() => asignar(resultado));
  }

  Future<void> _enviar() async {
    final identidad = _identidad!;
    if (!_formKey.currentState!.validate()) return;
    if (_matriculaMoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sube una foto de la matrícula de tu moto'),
        ),
      );
      return;
    }
    if (_licenciaConducir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sube una foto de tu licencia de conducir'),
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      final resultado = await ref
          .read(postulacionRepartidorRepositoryProvider)
          .enviarSolicitud(
            nombre: identidad.nombre,
            telefono: identidad.telefono,
            ci: identidad.ci,
            placaMoto: _placaCtrl.text.trim(),
            carnetAnverso: identidad.carnetAnverso,
            carnetReverso: identidad.carnetReverso,
            matriculaMoto: await _matriculaMoto!.readAsBytes(),
            licenciaConducir: await _licenciaConducir!.readAsBytes(),
            selfieFrente: identidad.selfieFrente,
            selfieLado: identidad.selfieLado,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resultado.aprobado
                  ? '¡Identidad confirmada! Ya puedes empezar a repartir pedidos.'
                  : '¡Listo! Un verificador revisará tu solicitud pronto.',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al enviar: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_identidad == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Repartir pedidos')),
        body: PasoVerificacionIdentidad(
          onVerificado: (identidad) => setState(() => _identidad = identidad),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repartir pedidos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _identidad = null),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Identidad verificada: ${_identidad!.nombreParaMostrar}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _placaCtrl,
              decoration: const InputDecoration(labelText: 'Placa de la moto'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa la placa' : null,
            ),
            const SizedBox(height: 20),
            const Text(
              'Matrícula (tarjeta de propiedad) de la moto',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _elegirFoto((f) => _matriculaMoto = f),
              icon: const Icon(Icons.two_wheeler_outlined),
              label: Text(
                _matriculaMoto == null
                    ? 'Subir foto de la matrícula'
                    : _matriculaMoto!.name,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Licencia de conducir de motos',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Se compara con tu selfie y tu carnet: si no coincide lo suficiente, '
              'tu solicitud queda para revisión manual.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _elegirFoto((f) => _licenciaConducir = f),
              icon: const Icon(Icons.card_membership_outlined),
              label: Text(
                _licenciaConducir == null
                    ? 'Subir foto de la licencia de conducir'
                    : _licenciaConducir!.name,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enviar solicitud'),
            ),
            if (_enviando) ...[
              const SizedBox(height: 8),
              const Text(
                'Verificando... puede tardar hasta 1 minuto si el servidor estaba dormido.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
