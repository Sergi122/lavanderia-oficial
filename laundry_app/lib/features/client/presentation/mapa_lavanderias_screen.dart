import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../shared/models/lavanderia.dart';
import '../data/lavanderia_repository.dart';

const _centroLaPaz = LatLng(-16.5000, -68.1500);
const _distancia = Distance();

class MapaLavanderiasScreen extends ConsumerStatefulWidget {
  /// Dentro del inicio del cliente: sin Scaffold, con altura fija.
  final bool embebido;
  const MapaLavanderiasScreen({super.key, this.embebido = false});

  @override
  ConsumerState<MapaLavanderiasScreen> createState() =>
      _MapaLavanderiasScreenState();
}

class _MapaLavanderiasScreenState extends ConsumerState<MapaLavanderiasScreen> {
  final _mapController = MapController();
  LatLng? _miUbicacion;
  String? _errorUbicacion;
  bool _buscandoUbicacion = true;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  Future<void> _obtenerUbicacion() async {
    setState(() {
      _buscandoUbicacion = true;
      _errorUbicacion = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _errorUbicacion =
              'Activa el GPS / servicio de ubicación de tu dispositivo.';
          _buscandoUbicacion = false;
        });
        return;
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        setState(() {
          _errorUbicacion = 'Necesitamos permiso de ubicación para mostrar lo más cerca de ti.';
          _buscandoUbicacion = false;
        });
        return;
      }

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final ubicacion = LatLng(posicion.latitude, posicion.longitude);
      setState(() {
        _miUbicacion = ubicacion;
        _buscandoUbicacion = false;
      });
      _mapController.move(ubicacion, 15);
    } catch (e) {
      setState(() {
        _errorUbicacion = 'No se pudo obtener tu ubicación: $e';
        _buscandoUbicacion = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lavanderiasAsync = ref.watch(lavanderiasProvider);
    final u = ref.watch(currentAppUserProvider).valueOrNull;
    final casa = (u?.ubicacionLat != null && u?.ubicacionLng != null)
        ? LatLng(u!.ubicacionLat!, u.ubicacionLng!)
        : null;

    final cuerpo = Stack(
      children: [
        lavanderiasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('No se pudo cargar el mapa: $e')),
          data: (lavanderias) {
            return FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _miUbicacion ?? casa ?? _centroLaPaz,
                initialZoom: (_miUbicacion ?? casa) != null ? 14.5 : 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.losasustadores.laundry_app',
                ),
                MarkerLayer(
                  markers: [
                    if (casa != null)
                      Marker(
                        point: casa,
                        width: 36,
                        height: 36,
                        child: Tooltip(
                          message: 'Mi casa',
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.home_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    if (_miUbicacion != null)
                      Marker(
                        point: _miUbicacion!,
                        width: 26,
                        height: 26,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final lav in lavanderias)
                      Marker(
                        point: LatLng(lav.lat, lav.lng),
                        width: 42,
                        height: 42,
                        child: GestureDetector(
                          onTap: () => _mostrarDetalle(context, lav),
                          child: const Icon(
                            Icons.location_on,
                            color: AppTheme.primary,
                            size: 42,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        if (_buscandoUbicacion)
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: _Chip(
                icon: Icons.my_location,
                texto: 'Buscando tu ubicación…',
              ),
            ),
          ),
        if (_errorUbicacion != null)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _Chip(
              icon: Icons.location_off,
              texto: _errorUbicacion!,
              accion: TextButton(
                onPressed: _obtenerUbicacion,
                child: const Text('Reintentar'),
              ),
            ),
          ),
      ],
    );

    if (widget.embebido) {
      return SizedBox(
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              cuerpo,
              Positioned(
                left: 10,
                bottom: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'mapa_ubicacion',
                      onPressed: _obtenerUbicacion,
                      tooltip: 'Centrar en mi ubicación',
                      child: const Icon(Icons.my_location),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'mapa_grande',
                      onPressed: () => context.push('/cliente/mapa'),
                      tooltip: 'Pantalla completa',
                      child: const Icon(Icons.fullscreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lavanderías cerca de ti')),
      body: cuerpo,
      floatingActionButton: FloatingActionButton(
        onPressed: _obtenerUbicacion,
        tooltip: 'Centrar en mi ubicación',
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _mostrarDetalle(BuildContext context, Lavanderia lavanderia) {
    final distanciaKm = _miUbicacion == null
        ? null
        : _distancia.as(
            LengthUnit.Kilometer,
            _miUbicacion!,
            LatLng(lavanderia.lat, lavanderia.lng),
          );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lavanderia.nombre,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                lavanderia.direccion,
                style: const TextStyle(color: Colors.black54),
              ),
              if (lavanderia.fotosBase64.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: lavanderia.fotosBase64.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        base64Decode(lavanderia.fotosBase64[index]),
                        width: 180,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
              Consumer(
                builder: (context, ref, _) {
                  final promedio = ref.watch(
                    calificacionPromedioProvider(lavanderia.id),
                  );
                  return promedio.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (valor) => valor == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  valor.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  );
                },
              ),
              if (distanciaKm != null) ...[
                const SizedBox(height: 4),
                Text(
                  'A ${distanciaKm.toStringAsFixed(1)} km de ti',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in lavanderia.servicios)
                    Chip(
                      label: Text(s),
                      backgroundColor: const Color(0xFFEFF6F6),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/cliente/nuevo-pedido', extra: lavanderia);
                  },
                  child: const Text('Pedir aquí'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Widget? accion;
  const _Chip({required this.icon, required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(30),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.black54),
            const SizedBox(width: 8),
            Flexible(child: Text(texto, style: const TextStyle(fontSize: 13))),
            ?accion,
          ],
        ),
      ),
    );
  }
}
