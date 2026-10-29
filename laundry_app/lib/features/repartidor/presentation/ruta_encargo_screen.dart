import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/routing/rutas.dart';
import '../../../core/theme/app_theme.dart';
import '../../client/data/lavanderia_repository.dart';
import '../../shared/models/pedido.dart';
import '../../shared/widgets/dashboard_widgets.dart';

const _naranja = Color(0xFFF57C00); // hacia la casa del cliente (recoger)
const _azul = Color(0xFF1565C0); // hacia la lavandería
const _verde = Color(0xFF2E7D32); // de vuelta al cliente (entregar)

/// Un tramo del recorrido que el repartidor tiene por delante.
class _Tramo {
  final String titulo;
  final Color color;
  final TramoRuta ruta;
  const _Tramo(this.titulo, this.color, this.ruta);
}

class _Plan {
  final LatLng yo;
  final LatLng cliente;
  final LatLng lavanderia;
  final List<_Tramo> tramos;
  final String ahora; // qué hacer ya mismo
  const _Plan(this.yo, this.cliente, this.lavanderia, this.tramos, this.ahora);
}

Future<LatLng> _ubicacionRepartidor() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw 'Activa la ubicación (GPS) para ver tu ruta';
  }
  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.denied ||
      permiso == LocationPermission.deniedForever) {
    throw 'Necesitamos permiso de ubicación para calcular tu ruta';
  }
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
  return LatLng(pos.latitude, pos.longitude);
}

/// Mapa del encargo: dónde estás tú, a dónde tienes que ir ahora y dónde se
/// entrega. Sirve para decidir un encargo disponible (devuelve `true` si lo
/// aceptas) y para seguir uno en curso según su etapa.
class RutaEncargoScreen extends ConsumerStatefulWidget {
  final Pedido pedido;
  final bool enCurso;
  const RutaEncargoScreen({
    super.key,
    required this.pedido,
    this.enCurso = false,
  });

  @override
  ConsumerState<RutaEncargoScreen> createState() => _RutaEncargoScreenState();
}

class _RutaEncargoScreenState extends ConsumerState<RutaEncargoScreen> {
  Future<_Plan>? _futuro;
  LatLng? _yoEnVivo;
  StreamSubscription<Position>? _gps;

  Pedido get p => widget.pedido;

  @override
  void initState() {
    super.initState();
    // el marcador "tú" se mueve mientras miras el mapa
    _gps =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (pos) =>
              setState(() => _yoEnVivo = LatLng(pos.latitude, pos.longitude)),
          onError: (_) {},
        );
  }

  @override
  void dispose() {
    _gps?.cancel();
    super.dispose();
  }

  Future<_Plan> _cargar(double lavLat, double lavLng) async {
    if (p.recojoLat == null || p.recojoLng == null) {
      throw 'Este pedido no trae la ubicación exacta del cliente';
    }
    final cliente = LatLng(p.recojoLat!, p.recojoLng!);
    final lav = LatLng(lavLat, lavLng);
    final yo = await _ubicacionRepartidor();
    final etapa = widget.enCurso ? p.etapaReparto : EtapaReparto.aceptado;
    Future<_Tramo> t(String titulo, Color c, LatLng a, LatLng b) async =>
        _Tramo(titulo, c, await calcularTramo(a, b));

    final (tramos, ahora) = switch (etapa) {
      EtapaReparto.aceptado => (
        await Future.wait([
          t('Tú → casa del cliente (recoger)', _naranja, yo, cliente),
          t('Casa del cliente → lavandería', _azul, cliente, lav),
        ]),
        'Ve a la casa del cliente a recoger la ropa',
      ),
      EtapaReparto.recogido => (
        [await t('Tú → lavandería (dejar la ropa)', _azul, yo, lav)],
        'Lleva la ropa a la lavandería',
      ),
      EtapaReparto.enLavanderia => (
        await Future.wait([
          t('Tú → lavandería (recoger limpia)', _azul, yo, lav),
          t('Lavandería → casa del cliente', _verde, lav, cliente),
        ]),
        p.estado == EstadoPedido.listo
            ? 'La ropa está lista: recógela en la lavandería'
            : 'La lavandería está lavando; te avisamos cuando esté lista',
      ),
      EtapaReparto.devolviendo => (
        [await t('Tú → casa del cliente (entregar)', _verde, yo, cliente)],
        'Entrega la ropa limpia al cliente',
      ),
      EtapaReparto.completada => (<_Tramo>[], 'Entrega completada'),
    };
    return _Plan(yo, cliente, lav, tramos, ahora);
  }

  @override
  Widget build(BuildContext context) {
    final lavAsync = ref.watch(lavanderiaPorIdProvider(p.lavanderiaId));
    final lav = lavAsync.valueOrNull;
    if (lav != null) _futuro ??= _cargar(lav.lat, lav.lng);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.enCurso ? 'Tu entrega' : p.lavanderiaNombre),
      ),
      body: _futuro == null
          ? Center(
              child: lavAsync.hasError
                  ? const Text('No se pudo cargar la lavandería')
                  : const CircularProgressIndicator(),
            )
          : FutureBuilder<_Plan>(
              future: _futuro,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('${snap.error}', textAlign: TextAlign.center),
                    ),
                  );
                }
                return _contenido(snap.data!);
              },
            ),
    );
  }

  Widget _contenido(_Plan d) {
    final yo = _yoEnVivo ?? d.yo;
    final todos = [
      yo,
      d.cliente,
      d.lavanderia,
      for (final t in d.tramos) ...t.ruta.puntos,
    ];
    final km = d.tramos.fold(0.0, (a, t) => a + t.ruta.km);
    final min = d.tramos.fold(0.0, (a, t) => a + t.ruta.minutos);
    final aprox = d.tramos.any((t) => t.ruta.aproximado);

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.coordinates(
                    coordinates: todos,
                    padding: const EdgeInsets.all(56),
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.losasustadores.laundry_app',
                  ),
                  PolylineLayer(
                    polylines: [
                      for (final t in d.tramos.reversed)
                        Polyline(
                          points: t.ruta.puntos,
                          strokeWidth: 6,
                          color: t.color,
                          borderStrokeWidth: 2,
                          borderColor: Colors.white,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      _marcador(
                        d.cliente,
                        Icons.home_rounded,
                        _naranja,
                        'Cliente',
                      ),
                      _marcador(
                        d.lavanderia,
                        Icons.local_laundry_service,
                        _azul,
                        'Lavandería',
                      ),
                      _marcador(yo, Icons.two_wheeler, Colors.black87, 'Tú'),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  color: AppTheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flag_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            d.ahora,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.checkroom_outlined,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${p.totalPrendas} prendas · '
                        '${resumenCarga(p.prendas, p.resumenRopaRegular)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (p.direccionRecojo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.home_outlined,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.direccionRecojo,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 20),
                for (final t in d.tramos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _fila(t.color, t.titulo, t.ruta),
                  ),
                if (d.tramos.isNotEmpty) ...[
                  const Divider(height: 14),
                  Text(
                    'Total: ${km.toStringAsFixed(1)} km · ~${min.round()} min'
                    '${widget.enCurso ? '' : ' por Bs ${p.costoEnvio.toStringAsFixed(0)}'}'
                    '${aprox ? '  (distancia aproximada)' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                if (!widget.enCurso) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('No me conviene'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Aceptar encargo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Marker _marcador(LatLng punto, IconData icono, Color color, String nombre) =>
      Marker(
        point: punto,
        width: 84,
        height: 64,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(icono, color: Colors.white, size: 20),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                nombre,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _fila(Color color, String titulo, TramoRuta t) => Row(
    children: [
      Container(
        width: 28,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(titulo, style: const TextStyle(fontSize: 13))),
      Text(
        '${t.km.toStringAsFixed(1)} km · ~${t.minutos.round()} min',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ],
  );
}
