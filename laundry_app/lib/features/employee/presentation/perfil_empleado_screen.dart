import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../legal/legal_screens.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../client/data/apertura_lavanderia_repository.dart';
import '../../client/data/empleo_repository.dart';
import '../../shared/models/app_user.dart';

class PerfilEmpleadoScreen extends ConsumerStatefulWidget {
  /// El repartidor usa la misma pantalla, sin bolsa de trabajo ni CV.
  final bool soloDatosPersonales;
  const PerfilEmpleadoScreen({super.key, this.soloDatosPersonales = false});

  @override
  ConsumerState<PerfilEmpleadoScreen> createState() =>
      _PerfilEmpleadoScreenState();
}

class _PerfilEmpleadoScreenState extends ConsumerState<PerfilEmpleadoScreen> {
  final _direccionCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  DateTime? _fechaNacimiento;
  String _fotoBase64 = '';
  Uint8List? _cvBytes;
  String _cvNombre = '';
  bool _inicializado = false;
  bool _guardando = false;

  @override
  void dispose() {
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _inicializar(AppUser appUser) {
    if (_inicializado) return;
    _direccionCtrl.text = appUser.direccion;
    _telefonoCtrl.text = appUser.telefono;
    _bioCtrl.text = appUser.bioEmpleado;
    _fechaNacimiento = appUser.fechaNacimiento;
    _fotoBase64 = appUser.fotoBase64;
    _cvNombre = appUser.cvNombre;
    _inicializado = true;
  }

  int? get _edadCalculada {
    final f = _fechaNacimiento;
    if (f == null) return null;
    final ahora = DateTime.now();
    var edad = ahora.year - f.year;
    if (ahora.month < f.month ||
        (ahora.month == f.month && ahora.day < f.day)) {
      edad--;
    }
    return edad;
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (elegida != null) setState(() => _fechaNacimiento = elegida);
  }

  Future<void> _elegirFoto() async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 70,
    );
    if (foto == null) return;
    final bytes = await foto.readAsBytes();
    if (bytes.length > maxTamanoFotoBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La foto pesa demasiado (máx. ${(maxTamanoFotoBytes / 1024).round()} KB).',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _fotoBase64 = base64Encode(bytes));
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
              'El CV pesa demasiado (máx. ${(maxTamanoCvBytes / 1024).round()} KB).',
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
    });
  }

  Future<void> _guardar(String uid) async {
    setState(() => _guardando = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .actualizarPerfilEmpleado(
            uid,
            direccion: _direccionCtrl.text.trim(),
            telefono: _telefonoCtrl.text.trim(),
            fechaNacimiento: _fechaNacimiento,
            fotoBase64: _fotoBase64.isEmpty ? null : _fotoBase64,
            cvBase64: _cvBytes == null ? null : base64Encode(_cvBytes!),
            cvNombre: _cvBytes == null ? null : _cvNombre,
          );
      if (!widget.soloDatosPersonales) {
        await ref
            .read(authRepositoryProvider)
            .actualizarBioEmpleado(uid, _bioCtrl.text.trim());
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Perfil guardado')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: appUser == null
          ? const Center(child: CircularProgressIndicator())
          : Builder(
              builder: (context) {
                _inicializar(appUser);
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _elegirFoto,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: AppTheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          backgroundImage: _fotoBase64.isEmpty
                              ? null
                              : MemoryImage(base64Decode(_fotoBase64)),
                          child: _fotoBase64.isEmpty
                              ? const Icon(
                                  Icons.add_a_photo_outlined,
                                  color: AppTheme.primary,
                                  size: 28,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: _elegirFoto,
                        child: Text(
                          _fotoBase64.isEmpty ? 'Agregar foto' : 'Cambiar foto',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      appUser.nombre,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      appUser.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Fecha de nacimiento',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _elegirFecha,
                      icon: const Icon(Icons.cake_outlined),
                      label: Text(
                        _fechaNacimiento == null
                            ? 'Elegir fecha'
                            : '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}'
                                  '${_edadCalculada != null ? ' · $_edadCalculada años' : ''}',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Teléfono de contacto',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _telefonoCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Tu número de celular',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Dónde vives',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _direccionCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Tu dirección',
                      ),
                    ),
                    if (!widget.soloDatosPersonales) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Busco trabajo (visible para admins)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bioCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Ej: 3 años lavando y planchando, disponible tiempo completo',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'CV',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _elegirCv,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(
                          _cvNombre.isEmpty
                              ? 'Subir CV (PDF o Word)'
                              : _cvNombre,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _guardando
                          ? null
                          : () => _guardar(appUser.uid),
                      child: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Guardar perfil'),
                    ),
                    const SizedBox(height: 16),
                    const SeccionPrivacidadCuenta(),
                  ],
                );
              },
            ),
    );
  }
}
