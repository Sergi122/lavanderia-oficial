import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ubicacion/ubicacion.dart';
import '../../auth/data/auth_repository.dart';

/// Punto elegido en el mapa, con su dirección legible.
typedef PuntoElegido = ({LatLng punto, String direccion});

/// Mapa a pantalla completa con un pin fijo al centro: el cliente arrastra el
/// mapa hasta su casa y toca "Aquí es mi casa". Se guarda en su perfil para
/// los siguientes pedidos y se devuelve a quien abrió la pantalla.
class MarcarCasaScreen extends ConsumerStatefulWidget {
  const MarcarCasaScreen({super.key});

  @override
  ConsumerState<MarcarCasaScreen> createState() => _MarcarCasaScreenState();
}

class _MarcarCasaScreenState extends ConsumerState<MarcarCasaScreen> {
  final _mapa = MapController();
  late LatLng _centro;
  String _direccion = '';
  bool _buscandoDireccion = false;
  bool _guardando = false;
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentAppUserProvider).valueOrNull;
    final casa = (u?.ubicacionLat != null && u?.ubicacionLng != null)
        ? LatLng(u!.ubicacionLat!, u.ubicacionLng!)
        : null;
    _centro = casa ?? centroLaPaz;
    _direccion = u?.direccion ?? '';
    if (casa == null) _irAMiUbicacion();
  }

  Future<void> _irAMiUbicacion() async {
    final r = await ubicacionActual();
    if (!mounted) return;
    if (r.punto != null) {
      _mapa.move(r.punto!, 17);
      _alMover(r.punto!);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.error!)));
    }
  }

  /// Al soltar el mapa se busca la dirección del nuevo centro (la última
  /// consulta gana, así no pisa una respuesta vieja a una nueva).
  Future<void> _alMover(LatLng centro) async {
    _centro = centro;
    final n = ++_consulta;
    setState(() => _buscandoDireccion = true);
    final d = await direccionDe(centro);
    if (!mounted || n != _consulta) return;
    setState(() {
      _buscandoDireccion = false;
      if (d != null) _direccion = d;
    });
  }

  Future<void> _confirmar() async {
    final u = ref.read(currentAppUserProvider).valueOrNull;
    if (u == null) return;
    setState(() => _guardando = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .guardarCasa(
            uid: u.uid,
            direccion: _direccion.isEmpty ? 'Mi casa' : _direccion,
            lat: _centro.latitude,
            lng: _centro.longitude,
          );
      if (!mounted) return;
      Navigator.of(context)
          .pop<PuntoElegido>((punto: _centro, direccion: _direccion));
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar tu casa: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿Dónde está tu casa?')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: _centro,
              initialZoom: 17,
              onMapEvent: (e) {
                if (e is MapEventMoveEnd ||
                    e is MapEventFlingAnimationEnd ||
                    e is MapEventDoubleTapZoomEnd) {
                  _alMover(e.camera.center);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.losasustadores.laundry_app',
              ),
            ],
          ),
          // Pin fijo: la punta queda exactamente en el centro del mapa.
          const IgnorePointer(child: Center(child: _PinCasa())),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.pan_tool_alt_outlined, color: AppTheme.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mueve el mapa hasta que el pin quede sobre tu casa',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 190,
            child: FloatingActionButton.small(
              heroTag: 'casa_gps',
              onPressed: _irAMiUbicacion,
              tooltip: 'Ir a mi ubicación actual',
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, color: Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _buscandoDireccion
                                ? 'Buscando la dirección…'
                                : (_direccion.isEmpty
                                      ? 'Dirección no disponible (igual puedes guardar el punto)'
                                      : _direccion),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _confirmar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.home_rounded),
                      label: const Text('Aquí es mi casa'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinCasa extends StatelessWidget {
  const _PinCasa();

  @override
  Widget build(BuildContext context) {
    // Alto total ≈ 58 px: se sube la mitad para que la punta marque el centro.
    return Transform.translate(
      offset: const Offset(0, -29),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.home_rounded, color: Colors.white),
          ),
          Container(width: 3, height: 12, color: AppTheme.primary),
        ],
      ),
    );
  }
}
