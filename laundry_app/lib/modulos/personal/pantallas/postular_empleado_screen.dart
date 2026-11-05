import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/verificacion/paso_identidad.dart';
import '../../../core/contrato/datos/empleo_repository.dart';
import '../../../core/contrato/datos/lavanderia_repository.dart';

String _formatoKb(int bytes) => '${(bytes / 1024).round()} KB';

class PostularEmpleadoScreen extends ConsumerStatefulWidget {
  final VerificacionIdentidad? identidadInicial;

  const PostularEmpleadoScreen({super.key, this.identidadInicial});

  @override
  ConsumerState<PostularEmpleadoScreen> createState() =>
      _PostularEmpleadoScreenState();
}

class _PostularEmpleadoScreenState
    extends ConsumerState<PostularEmpleadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _direccionCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  String? _lavanderiaSeleccionada;
  Uint8List? _cvBytes;
  String _cvNombre = '';
  int _cvTamano = 0;
  bool _enviando = false;

  late VerificacionIdentidad? _identidad = widget.identidadInicial;

  @override
  void dispose() {
    _direccionCtrl.dispose();
    _edadCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirCv() async {
    final archivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (archivo == null) return;

    final tamano = await archivo.length() ?? 0;
    if (tamano > maxTamanoCvBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ese archivo pesa ${_formatoKb(tamano)}, el máximo es '
              '${_formatoKb(maxTamanoCvBytes)}. Sube uno más liviano.',
            ),
          ),
        );
      }
      return;
    }

    final bytes = await archivo.readAsBytes();
    setState(() {
      _cvBytes = bytes;
      _cvNombre = archivo.name;
      _cvTamano = tamano;
    });
  }

  Future<void> _enviar() async {
    final identidad = _identidad!;
    if (!_formKey.currentState!.validate()) return;
    if (_lavanderiaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige en qué lavandería quieres trabajar'),
        ),
      );
      return;
    }
    if (_cvBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sube tu CV (PDF o Word)')));
      return;
    }

    setState(() => _enviando = true);
    try {
      await ref
          .read(empleoRepositoryProvider)
          .enviarSolicitud(
            nombre: identidad.nombre,
            direccion: _direccionCtrl.text.trim(),
            edad: int.parse(_edadCtrl.text.trim()),
            ci: identidad.ci,
            telefono: identidad.telefono,
            lavanderiaId: _lavanderiaSeleccionada!,
            archivoCv: _cvBytes!,
            nombreArchivoCv: _cvNombre,
            carnetAnverso: identidad.carnetAnverso,
            carnetReverso: identidad.carnetReverso,
            selfieFrente: identidad.selfieFrente,
            selfieLado: identidad.selfieLado,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Listo! El admin de la lavandería revisará tu solicitud.',
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
        appBar: AppBar(title: const Text('Trabajar como empleado')),
        body: PasoVerificacionIdentidad(
          onVerificado: (identidad) => setState(() => _identidad = identidad),
        ),
      );
    }

    final lavanderiasAsync = ref.watch(lavanderiasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trabajar como empleado'),
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
            lavanderiasAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) =>
                  Text('No se pudieron cargar las lavanderías: $e'),
              data: (lavanderias) => DropdownButtonFormField<String>(
                initialValue: _lavanderiaSeleccionada,
                decoration: const InputDecoration(labelText: 'Lavandería'),
                items: [
                  for (final lav in lavanderias)
                    DropdownMenuItem(value: lav.id, child: Text(lav.nombre)),
                ],
                onChanged: (v) => setState(() => _lavanderiaSeleccionada = v),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _direccionCtrl,
              decoration: const InputDecoration(labelText: 'Dónde vives'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ingresa tu dirección'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _edadCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Edad'),
              validator: (v) => (v == null || int.tryParse(v) == null)
                  ? 'Edad inválida'
                  : null,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _elegirCv,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                _cvBytes == null
                    ? 'Subir CV (PDF o Word, máx. ${_formatoKb(maxTamanoCvBytes)})'
                    : '$_cvNombre (${_formatoKb(_cvTamano)})',
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
