import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../widgets/abanico_cartas.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/auth/data/auth_repository.dart';
import 'capturador_carnet.dart';
import 'capturador_selfie_en_vivo.dart';
import 'comparador_rostros.dart';
import 'validador_carnet.dart';

/// Datos comunes a cualquiera que quiera trabajar (empleado, repartidor o
/// dueño de lavandería): quién es y su identidad confirmada con carnet +
/// selfie en vivo. Se captura una sola vez, antes de elegir el rol.
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

/// Paso 1 del flujo para trabajar con nosotros: verificar que sos una
/// persona real antes de dejarte elegir entre empleado, repartidor o abrir
/// tu lavandería. Es el mismo paso para los tres — solo cambia lo que se
/// pide DESPUÉS de esto.
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
  Uint8List? _carnetAnverso;
  Uint8List? _carnetReverso;
  ParSelfies? _selfies;
  bool _verificandoCarnet = false;
  bool _comparando = false;
  bool _rechazado = false;
  ResultadoComparacion? _comparacion;

  @override
  void initState() {
    super.initState();
    final nombreActual =
        ref.read(currentAppUserProvider).valueOrNull?.nombre ?? '';
    _nombreCtrl = TextEditingController(text: nombreActual);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ciCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirCarnet({required bool anverso}) async {
    // En la web no ofrecemos "tomar foto" (poco confiable desde el
    // navegador), directo a la galería. En el celular se deja elegir.
    ImageSource? fuente = ImageSource.gallery;
    if (!kIsWeb) {
      fuente = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de galería'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }
    if (fuente == null || !mounted) return;

    Uint8List? bytes;
    if (fuente == ImageSource.camera) {
      // Cámara con marco de carnet: recorta solo la tarjeta.
      bytes = await CapturadorCarnet.abrir(
        context,
        titulo: anverso ? 'Anverso del carnet' : 'Reverso del carnet',
      );
    } else {
      final resultado = await ImagePicker().pickImage(
        source: fuente,
        maxWidth: 700,
        imageQuality: 55,
      );
      bytes = await resultado?.readAsBytes();
    }
    if (bytes == null || !mounted) return;
    final carnetBytes = bytes;
    setState(() {
      if (anverso) {
        _comparacion = null;
        _carnetAnverso = carnetBytes;
      } else {
        _carnetReverso = carnetBytes;
      }
    });
  }

  void _eliminarCarnet({required bool anverso}) {
    setState(() {
      if (anverso) {
        _comparacion = null;
        _carnetAnverso = null;
      } else {
        _carnetReverso = null;
      }
    });
  }

  Future<void> _mostrarRechazoYReiniciar() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 36),
        title: const Text('Verificación rechazada'),
        content: const Text(
          'Tu rostro no coincide con el del carnet. '
          'Vuelve a intentarlo más tarde; se reiniciará todo el formulario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _nombreCtrl.clear();
      _ciCtrl.clear();
      _telefonoCtrl.clear();
      _carnetAnverso = null;
      _carnetReverso = null;
      _selfies = null;
      _comparacion = null;
      _rechazado = false;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _compararRostros(ParSelfies par) async {
    final anverso = _carnetAnverso;
    if (anverso == null) return;
    setState(() {
      _selfies = par;
      _comparando = true;
      _comparacion = null;
    });
    final r = await compararCarnetConSelfie(
      carnetAnverso: anverso,
      selfieFrente: par.frente,
    );
    if (!mounted) return;
    setState(() {
      _comparando = false;
      _comparacion = r;
      // Si no es la misma persona, se descarta la selfie para repetirla.
      if (r.estado == EstadoComparacion.noCoincide) {
        // Rechazo directo: sin opción de reintentar; se avisa y se
        // reinicia todo el formulario.
        _rechazado = true;
        _selfies = null;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _mostrarRechazoYReiniciar(),
        );
      } else if (r.estado == EstadoComparacion.sinRostroSelfie) {
        _selfies = null;
      }
    });
  }

  Future<void> _continuar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_carnetAnverso == null || _carnetReverso == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sube el anverso y el reverso de tu carnet'),
        ),
      );
      return;
    }
    if (_selfies == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa la verificación con la cámara')),
      );
      return;
    }
    if (_comparando) return;
    if (_rechazado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verificación rechazada: tu rostro no coincide con el carnet.',
          ),
        ),
      );
      return;
    }
    if (_comparacion?.estado == EstadoComparacion.sinRostroCarnet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se ve la cara en la foto del carnet. Vuelve a tomar el anverso.',
          ),
        ),
      );
      return;
    }

    if (!kIsWeb) {
      setState(() => _verificandoCarnet = true);
      final lectura = await verificarNumeroCarnet(
        fotoAnverso: _carnetAnverso!,
        ciEscrito: _ciCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _verificandoCarnet = false);
      if (!lectura.coincide) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El número de carnet que escribiste no coincide con el de la foto. '
              'Revísalo o vuelve a tomar la foto del anverso.',
            ),
          ),
        );
        return;
      }
    }

    widget.onVerificado(
      VerificacionIdentidad(
        nombre: _nombreCtrl.text.trim(),
        ci: _ciCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        carnetAnverso: _carnetAnverso!,
        carnetReverso: _carnetReverso!,
        selfieFrente: _selfies!.frente,
        selfieLado: _selfies!.lado,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Verifica que eres tú',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 4),
          const Text(
            'Antes de trabajar con nosotros necesitamos confirmar tu identidad. '
            'Esto se hace una sola vez.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _ciCtrl,
            decoration: const InputDecoration(labelText: 'Carnet de identidad'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa tu CI' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _telefonoCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Celular'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa tu celular' : null,
          ),
          const SizedBox(height: 20),
          const Text(
            'Carnet de identidad (anverso y reverso)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _CampoFotoCarnet(
            etiqueta: 'anverso',
            bytes: _carnetAnverso,
            onElegir: () => _elegirCarnet(anverso: true),
            onEliminar: () => _eliminarCarnet(anverso: true),
          ),
          const SizedBox(height: 10),
          _CampoFotoCarnet(
            etiqueta: 'reverso',
            bytes: _carnetReverso,
            onElegir: () => _elegirCarnet(anverso: false),
            onEliminar: () => _eliminarCarnet(anverso: false),
          ),
          const SizedBox(height: 24),
          const Text(
            'Verificación con cámara',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mira a la cámara, luego gira la cabeza cuando se te pida. '
            'La foto se toma sola cuando el círculo se completa.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (_carnetAnverso == null || _carnetReverso == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Sube primero el carnet para poder verificarte con la cámara.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            )
          else if (_comparando)
            const AnimacionVerificacionFoto()
          else if (_selfies != null) ...[
            if (_comparacion != null &&
                _comparacion!.estado != EstadoComparacion.coincide)
              _AvisoComparacion(resultado: _comparacion!),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _comparacion?.estado == EstadoComparacion.coincide
                          ? 'Verificación aprobada'
                          : 'Verificación con cámara completada',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_rechazado)
            const _AvisoComparacion(
              resultado: ResultadoComparacion(EstadoComparacion.noCoincide),
            )
          else ...[
            if (_comparacion != null &&
                _comparacion!.estado != EstadoComparacion.coincide)
              _AvisoComparacion(resultado: _comparacion!),
            CapturadorSelfieEnVivo(onCompletado: _compararRostros),
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _verificandoCarnet ? null : _continuar,
            child: _verificandoCarnet
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

/// Campo de una cara del carnet: botón para elegir foto (cámara o galería
/// en el celular; galería en la web) o, si ya hay una, su vista previa con
/// opción de eliminarla para volver a elegir.
class _CampoFotoCarnet extends StatelessWidget {
  final String etiqueta;
  final Uint8List? bytes;
  final VoidCallback onElegir;
  final VoidCallback onEliminar;

  const _CampoFotoCarnet({
    required this.etiqueta,
    required this.bytes,
    required this.onElegir,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final foto = bytes;
    if (foto == null) {
      return OutlinedButton.icon(
        onPressed: onElegir,
        icon: const Icon(Icons.badge_outlined),
        label: Text('Subir $etiqueta del carnet'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(foto, width: 48, height: 48, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${etiqueta[0].toUpperCase()}${etiqueta.substring(1)} listo',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: onEliminar,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Eliminar foto',
          ),
        ],
      ),
    );
  }
}

class _AvisoComparacion extends StatelessWidget {
  final ResultadoComparacion resultado;
  const _AvisoComparacion({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final texto = switch (resultado.estado) {
      EstadoComparacion.noCoincide =>
        'Verificación rechazada. Vuelve a intentarlo más tarde.',
      EstadoComparacion.sinRostroSelfie => 'No se pudo leer bien tu rostro en la selfie. Repite la verificación con buena luz.',
      EstadoComparacion.sinRostroCarnet => 'No se ve la cara en la foto del carnet. Vuelve a tomar el anverso con el marco, con buena luz y sin reflejos.',
      _ => 'No se pudo comparar tu rostro con el carnet; lo revisará el verificador.',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
