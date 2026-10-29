import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/verificacion/paso_identidad.dart';
import '../../shared/models/tipos_prenda.dart';
import '../data/apertura_lavanderia_repository.dart';

const _catalogoServicios = ['Lavado', 'Secado', 'Planchado', 'Lavado en seco'];

const _centroLaPaz = LatLng(-16.5000, -68.1500);

class AbrirLavanderiaScreen extends ConsumerStatefulWidget {
  final VerificacionIdentidad? identidadInicial;

  const AbrirLavanderiaScreen({super.key, this.identidadInicial});

  @override
  ConsumerState<AbrirLavanderiaScreen> createState() =>
      _AbrirLavanderiaScreenState();
}

class _AbrirLavanderiaScreenState extends ConsumerState<AbrirLavanderiaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _costoEnvioCtrl = TextEditingController(text: '0');
  final _precioDocenaCtrl = TextEditingController();
  final _precioKgCtrl = TextEditingController();
  final _preciosEspecialesCtrl = <String, TextEditingController>{
    for (final s in prendasEspeciales) s: TextEditingController(),
  };
  final _preciosRegularesCtrl = <String, TextEditingController>{
    for (final s in prendasRegulares) s: TextEditingController(),
  };

  final _servicios = <String>{};
  bool _mostrarPrecios = false;
  bool _entregaDomicilio = false;
  LatLng? _ubicacion;
  bool _buscandoDireccion = false;
  final _fotos = <XFile>[];
  bool _enviando = false;

  late VerificacionIdentidad? _identidad = widget.identidadInicial;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _nitCtrl.dispose();
    _direccionCtrl.dispose();
    _costoEnvioCtrl.dispose();
    _precioDocenaCtrl.dispose();
    _precioKgCtrl.dispose();
    for (final c in _preciosEspecialesCtrl.values) {
      c.dispose();
    }
    for (final c in _preciosRegularesCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _actualizarDireccionDesde(LatLng punto) async {
    setState(() => _buscandoDireccion = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=${punto.latitude}&lon=${punto.longitude}',
      );
      final respuesta = await http
          .get(uri, headers: {'User-Agent': 'com.losasustadores.laundry_app'})
          .timeout(const Duration(seconds: 6));
      if (respuesta.statusCode == 200) {
        final data = jsonDecode(respuesta.body) as Map<String, dynamic>;
        final direccion = data['display_name'] as String?;
        if (direccion != null && mounted) {
          setState(() => _direccionCtrl.text = direccion);
        }
      }
    } catch (_) {
      // si falla el servicio de mapas, el dueño escribe la dirección a mano
    } finally {
      if (mounted) setState(() => _buscandoDireccion = false);
    }
  }

  Future<void> _usarMiUbicacion() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return;
      }
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final punto = LatLng(posicion.latitude, posicion.longitude);
      setState(() => _ubicacion = punto);
      await _actualizarDireccionDesde(punto);
    } catch (_) {
      // el usuario puede marcar el punto directamente en el mapa
    }
  }

  Future<void> _elegirFotos() async {
    final resultado = await ImagePicker().pickMultiImage(
      maxWidth: 700,
      imageQuality: 55,
    );
    if (resultado.isEmpty) return;
    setState(() {
      _fotos
        ..clear()
        ..addAll(resultado.take(maxFotosLavanderia));
    });
  }

  Future<void> _enviar() async {
    final identidad = _identidad!;
    if (!_formKey.currentState!.validate()) return;
    if (_servicios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige al menos un servicio')),
      );
      return;
    }
    if (_ubicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marca la ubicación de tu lavandería en el mapa'),
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      final precios = <String, double>{
        for (final s in prendasEspeciales)
          if (_mostrarPrecios &&
              _preciosEspecialesCtrl[s]!.text.trim().isNotEmpty)
            s: double.tryParse(_preciosEspecialesCtrl[s]!.text.trim()) ?? 0,
        for (final s in prendasRegulares)
          if (_mostrarPrecios &&
              _preciosRegularesCtrl[s]!.text.trim().isNotEmpty)
            s: double.tryParse(_preciosRegularesCtrl[s]!.text.trim()) ?? 0,
      };
      final precioDocena =
          (_mostrarPrecios && _precioDocenaCtrl.text.trim().isNotEmpty)
          ? double.tryParse(_precioDocenaCtrl.text.trim())
          : null;
      final precioKg = (_mostrarPrecios && _precioKgCtrl.text.trim().isNotEmpty)
          ? double.tryParse(_precioKgCtrl.text.trim())
          : null;

      final resultado = await ref
          .read(aperturaLavanderiaRepositoryProvider)
          .enviarSolicitud(
            nombrePropietario: identidad.nombre,
            ciPropietario: identidad.ci,
            telefonoPropietario: identidad.telefono,
            nombre: _nombreCtrl.text.trim(),
            nit: _nitCtrl.text.trim(),
            direccion: _direccionCtrl.text.trim(),
            lat: _ubicacion!.latitude,
            lng: _ubicacion!.longitude,
            servicios: _servicios.toList(),
            precios: precios,
            mostrarPrecios: _mostrarPrecios,
            precioDocena: precioDocena,
            precioKg: precioKg,
            costoEnvio: double.tryParse(_costoEnvioCtrl.text.trim()) ?? 0,
            entregaDomicilio: _entregaDomicilio,
            fotos: [for (final f in _fotos) await f.readAsBytes()],
            carnetAnverso: identidad.carnetAnverso,
            carnetReverso: identidad.carnetReverso,
            selfieFrente: identidad.selfieFrente,
            selfieLado: identidad.selfieLado,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resultado.aprobado
                  ? '¡Identidad confirmada! Un superadmin revisará el local antes de publicarlo.'
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
        appBar: AppBar(title: const Text('Abrir mi lavandería')),
        body: PasoVerificacionIdentidad(
          onVerificado: (identidad) => setState(() => _identidad = identidad),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abrir mi lavandería'),
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
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la lavandería',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nitCtrl,
              decoration: const InputDecoration(labelText: 'NIT (opcional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _direccionCtrl,
              decoration: InputDecoration(
                labelText: 'Dirección',
                suffixIcon: _buscandoDireccion
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ingresa la dirección'
                  : null,
            ),
            const SizedBox(height: 20),
            const Text(
              'Marca la ubicación exacta en el mapa',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'La dirección se completa sola; puedes editarla si no queda exacta.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _ubicacion ?? _centroLaPaz,
                        initialZoom: 13,
                        onTap: (tapPos, point) {
                          setState(() => _ubicacion = point);
                          _actualizarDireccionDesde(point);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.losasustadores.laundry_app',
                        ),
                        if (_ubicacion != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _ubicacion!,
                                width: 42,
                                height: 42,
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppTheme.primary,
                                  size: 42,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: FloatingActionButton.small(
                        onPressed: _usarMiUbicacion,
                        tooltip: 'Usar mi ubicación',
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¿Qué servicios ofreces?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _catalogoServicios)
                  FilterChip(
                    label: Text(s),
                    selected: _servicios.contains(s),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _servicios.add(s);
                      } else {
                        _servicios.remove(s);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar precios a los clientes'),
              subtitle: const Text(
                'Si lo dejas apagado, los clientes verán "a consultar"',
              ),
              value: _mostrarPrecios,
              onChanged: (v) => setState(() => _mostrarPrecios = v),
            ),
            if (_mostrarPrecios) ...[
              const SizedBox(height: 8),
              const Text(
                'Precio por pieza de prendas delicadas',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              for (final s in prendasEspeciales)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _preciosEspecialesCtrl[s],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: '$s (Bs, opcional)'),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Precio por pieza de ropa regular',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              for (final s in prendasRegulares)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _preciosRegularesCtrl[s],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: '$s (Bs, opcional)'),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Descuento por cantidad de ropa regular (opcional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'Si un cliente trae mucha ropa, puede pagar por docena o por kilo '
                'en vez de pieza por pieza. Déjalo vacío si no ofreces esto.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _precioDocenaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio por docena (Bs, opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _precioKgCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio por kg (Bs, opcional)',
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ofrezco recojo a domicilio'),
              value: _entregaDomicilio,
              onChanged: (v) => setState(() => _entregaDomicilio = v),
            ),
            if (_entregaDomicilio)
              TextFormField(
                controller: _costoEnvioCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Costo del recojo (Bs)',
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Fotos de tu local (hasta 3)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _elegirFotos,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _fotos.isEmpty
                    ? 'Elegir fotos'
                    : '${_fotos.length} foto(s) elegidas',
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
