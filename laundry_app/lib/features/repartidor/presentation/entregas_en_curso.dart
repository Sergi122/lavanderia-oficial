import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../client/data/lavanderia_repository.dart';
import '../../shared/models/pedido.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../data/repartidor_repository.dart';
import 'ruta_encargo_screen.dart';

/// Entregas que el repartidor tiene aceptadas. Mientras hay alguna abierta
/// publica su ubicación para que el cliente lo siga en el mapa.
class TabEntregasEnCurso extends ConsumerStatefulWidget {
  const TabEntregasEnCurso({super.key});

  @override
  ConsumerState<TabEntregasEnCurso> createState() => _TabEntregasEnCursoState();
}

class _TabEntregasEnCursoState extends ConsumerState<TabEntregasEnCurso> {
  StreamSubscription<Position>? _sub;
  DateTime _ultimoEnvio = DateTime(0);
  List<String> _ids = const [];
  bool _iniciando = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _sincronizarSeguimiento(List<Pedido> pedidos) async {
    _ids = [for (final p in pedidos) p.id];
    if (_ids.isEmpty) {
      await _sub?.cancel();
      _sub = null;
      return;
    }
    if (_sub != null || _iniciando) return;
    _iniciando = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied)
        permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return;
      }
      _sub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 25,
            ),
          ).listen((pos) {
            // como mucho una escritura cada 15 s
            if (DateTime.now().difference(_ultimoEnvio).inSeconds < 15) return;
            _ultimoEnvio = DateTime.now();
            for (final id in _ids) {
              ref
                  .read(repartidorRepositoryProvider)
                  .publicarUbicacion(id, pos.latitude, pos.longitude)
                  .catchError((_) {});
            }
          });
    } catch (_) {
    } finally {
      _iniciando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedidosAsync = ref.watch(misEntregasProvider);

    return pedidosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar tus entregas: $e')),
      data: (pedidos) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _sincronizarSeguimiento(pedidos),
        );
        if (pedidos.isEmpty) {
          return const EstadoVacio(
            icono: Icons.two_wheeler,
            mensaje: 'No tienes entregas en curso.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (var i = 0; i < pedidos.length; i++)
              _EntregaCard(pedido: pedidos[i])
                  .animate()
                  .fadeIn(delay: (i * 70).ms, duration: 350.ms)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          ],
        );
      },
    );
  }
}

class _EntregaCard extends ConsumerStatefulWidget {
  final Pedido pedido;
  const _EntregaCard({required this.pedido});

  @override
  ConsumerState<_EntregaCard> createState() => _EntregaCardState();
}

class _EntregaCardState extends ConsumerState<_EntregaCard> {
  bool _trabajando = false;

  Pedido get p => widget.pedido;

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() => _trabajando = true);
    try {
      await accion();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _entregarConFoto() async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      imageQuality: 50,
    );
    if (foto == null) return;
    final bytes = await foto.readAsBytes();
    if (bytes.length > 300 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La foto pesa demasiado, toma otra más simple.'),
          ),
        );
      }
      return;
    }
    await _ejecutar(
      () => ref
          .read(repartidorRepositoryProvider)
          .completarEntrega(p.id, base64Encode(bytes)),
    );
  }

  Future<void> _navegar(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final lav = ref.watch(lavanderiaPorIdProvider(p.lavanderiaId)).valueOrNull;
    final etapa = p.etapaReparto;
    final repo = ref.read(repartidorRepositoryProvider);

    // (texto del botón, acción, destino para navegar, mensaje de espera)
    String? textoBoton;
    VoidCallback? accion;
    ({double lat, double lng})? destino;
    String? espera;
    switch (etapa) {
      case EtapaReparto.aceptado:
        textoBoton = 'Ya recogí la ropa';
        accion = () =>
            _ejecutar(() => repo.avanzarEtapa(p.id, EtapaReparto.recogido));
        if (p.recojoLat != null)
          destino = (lat: p.recojoLat!, lng: p.recojoLng!);
      case EtapaReparto.recogido:
        textoBoton = 'Dejé la ropa en la lavandería';
        accion = () =>
            _ejecutar(() => repo.avanzarEtapa(p.id, EtapaReparto.enLavanderia));
        if (lav != null) destino = (lat: lav.lat, lng: lav.lng);
      case EtapaReparto.enLavanderia:
        if (p.estado == EstadoPedido.listo) {
          textoBoton = 'Recogí la ropa limpia';
          accion = () => _ejecutar(
            () => repo.avanzarEtapa(p.id, EtapaReparto.devolviendo),
          );
          if (lav != null) destino = (lat: lav.lat, lng: lav.lng);
        } else {
          espera =
              'Esperando a que la lavandería termine (${p.estado.label}). '
              'Te avisaremos cuando esté lista.';
        }
      case EtapaReparto.devolviendo:
        textoBoton = 'Entregué al cliente (tomar foto)';
        accion = _entregarConFoto;
        if (p.recojoLat != null)
          destino = (lat: p.recojoLat!, lng: p.recojoLng!);
      case EtapaReparto.completada:
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.lavanderiaNombre,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _Progreso(actual: etapa),
            const SizedBox(height: 8),
            Text(
              p.direccionRecojo.isEmpty
                  ? 'Sin dirección escrita'
                  : p.direccionRecojo,
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              '${p.totalPrendas} prendas · ${resumenCarga(p.prendas, p.resumenRopaRegular)}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (espera != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(espera, style: const TextStyle(fontSize: 13)),
              ),
            if (p.recojoLat != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RutaEncargoScreen(pedido: p, enCurso: true),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ver mapa: dónde estoy y a dónde voy'),
                  ),
                ),
              ),
            if (destino != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _navegar(destino!.lat, destino.lng),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Navegar al destino'),
                  ),
                ),
              ),
            if (textoBoton != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _trabajando ? null : accion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _trabajando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(textoBoton),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Barra de 4 pasos: recoger, llevar, traer de vuelta, entregar.
class _Progreso extends StatelessWidget {
  final EtapaReparto actual;
  const _Progreso({required this.actual});

  static const _pasos = ['Recoger', 'Llevar', 'Traer', 'Entregar'];

  @override
  Widget build(BuildContext context) {
    // etapa aceptado=0 (yendo a recoger) ... devolviendo=3 (yendo a entregar)
    final indice = actual.index.clamp(0, 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _pasos.length; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: 400.ms,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i <= indice ? AppTheme.primary : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Paso ${indice + 1} de 4: ${_pasos[indice]}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}
