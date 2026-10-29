import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';

const _centroLaPaz = LatLng(-16.5000, -68.1500);

/// Paso obligatorio para un cliente recién registrado: nombres, apellidos y
/// el punto de donde se recogerá su ropa. Es solo para clientes y NO pide
/// verificación de identidad (carnet/selfie).
class CompletarPerfilScreen extends ConsumerStatefulWidget {
  const CompletarPerfilScreen({super.key});

  @override
  ConsumerState<CompletarPerfilScreen> createState() =>
      _CompletarPerfilScreenState();
}

class _CompletarPerfilScreenState extends ConsumerState<CompletarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _mapa = MapController();
  LatLng? _ubicacion;
  bool _buscandoDireccion = false;
  bool _ubicando = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // Lo que escribió al registrarse se usa como punto de partida.
    final u = ref.read(currentAppUserProvider).valueOrNull;
    if (u != null) {
      _nombresCtrl.text = u.nombres.isNotEmpty ? u.nombres : u.nombre;
      _apellidosCtrl.text = u.apellidos;
      _direccionCtrl.text = u.direccion;
      if (u.ubicacionLat != null && u.ubicacionLng != null) {
        _ubicacion = LatLng(u.ubicacionLat!, u.ubicacionLng!);
      }
    }
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _direccionCtrl.dispose();
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
      // sin internet o servicio caído: la dirección se escribe a mano
    } finally {
      if (mounted) setState(() => _buscandoDireccion = false);
    }
  }

  Future<void> _usarMiUbicacion() async {
    setState(() => _ubicando = true);
    String? error;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = 'Activa la ubicación (GPS) de tu celular';
      } else {
        var permiso = await Geolocator.checkPermission();
        if (permiso == LocationPermission.denied) {
          permiso = await Geolocator.requestPermission();
        }
        if (permiso == LocationPermission.denied ||
            permiso == LocationPermission.deniedForever) {
          error = 'Da permiso de ubicación o marca el punto en el mapa';
        } else {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          final punto = LatLng(pos.latitude, pos.longitude);
          setState(() => _ubicacion = punto);
          _mapa.move(punto, 16);
          await _actualizarDireccionDesde(punto);
        }
      }
    } catch (_) {
      error = 'No pudimos obtener tu ubicación. Márcala en el mapa.';
    }
    if (!mounted) return;
    setState(() => _ubicando = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ubicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marca en el mapa dónde recogemos tu ropa'),
        ),
      );
      return;
    }
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .completarPerfilCliente(
            uid: uid,
            nombres: _nombresCtrl.text.trim(),
            apellidos: _apellidosCtrl.text.trim(),
            direccion: _direccionCtrl.text.trim(),
            lat: _ubicacion!.latitude,
            lng: _ubicacion!.longitude,
          );
      // El router redirige solo al inicio cuando el perfil queda completo.
      if (mounted) context.go('/cliente');
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar tu perfil. Revisa tu conexión.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Completa tu perfil'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).cerrarSesion(),
            child: const Text('Salir'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Antes de pedir, cuéntanos quién eres',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 4),
            const Text(
              'Usamos tu nombre para tus pedidos y tu ubicación para saber dónde recoger tu ropa. '
              'No necesitas carnet ni selfie.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombresCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombres'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ingresa tus nombres'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _apellidosCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Apellidos'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ingresa tus apellidos'
                  : null,
            ),
            const SizedBox(height: 24),
            const Text(
              '¿Dónde recogemos tu ropa?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Toca el mapa para marcar el punto exacto o usa tu ubicación actual. '
              'La dirección se completa sola y puedes editarla.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapa,
                      options: MapOptions(
                        initialCenter: _ubicacion ?? _centroLaPaz,
                        initialZoom: _ubicacion == null ? 13 : 16,
                        onTap: (tapPos, punto) {
                          setState(() => _ubicacion = punto);
                          _actualizarDireccionDesde(punto);
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
                        onPressed: _ubicando ? null : _usarMiUbicacion,
                        tooltip: 'Usar mi ubicación',
                        child: _ubicando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _direccionCtrl,
              decoration: InputDecoration(
                labelText: 'Dirección de recojo',
                prefixIcon: const Icon(Icons.location_on_outlined),
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
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar y continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
