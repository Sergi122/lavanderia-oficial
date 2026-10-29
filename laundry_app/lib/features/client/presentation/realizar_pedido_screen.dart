import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ubicacion/ubicacion.dart';
import '../../auth/data/auth_repository.dart';
import '../../shared/models/lavanderia.dart';
import '../data/lavanderia_repository.dart';
import 'marcar_casa_screen.dart';
import 'nuevo_pedido_screen.dart';

enum _Origen { actual, casa }

/// Realizar pedido en dos pasos:
/// 1. ¿Desde dónde? — ubicación actual (GPS) o "mi casa" (marcada en el mapa).
/// 2. ¿Qué lavandería? — las más cercanas a ese punto, ordenadas por distancia.
class RealizarPedidoScreen extends ConsumerStatefulWidget {
  const RealizarPedidoScreen({super.key});

  @override
  ConsumerState<RealizarPedidoScreen> createState() =>
      _RealizarPedidoScreenState();
}

class _RealizarPedidoScreenState extends ConsumerState<RealizarPedidoScreen> {
  _Origen? _origen;
  LatLng? _punto;
  String _direccion = '';
  bool _ubicando = false;

  Future<void> _elegirActual() async {
    setState(() {
      _ubicando = true;
      _origen = _Origen.actual;
    });
    final r = await ubicacionActual();
    if (!mounted) return;
    if (r.punto == null) {
      setState(() {
        _ubicando = false;
        _origen = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.error!)));
      return;
    }
    setState(() {
      _punto = r.punto;
      _direccion = 'Mi ubicación actual';
      _ubicando = false;
    });
    final d = await direccionDe(r.punto!);
    if (mounted && d != null) setState(() => _direccion = d);
  }

  void _elegirCasaGuardada(double lat, double lng, String direccion) {
    setState(() {
      _origen = _Origen.casa;
      _punto = LatLng(lat, lng);
      _direccion = direccion;
    });
  }

  Future<void> _marcarCasa() async {
    final r = await Navigator.of(context).push<PuntoElegido>(
      MaterialPageRoute(builder: (_) => const MarcarCasaScreen()),
    );
    if (r == null || !mounted) return;
    setState(() {
      _origen = _Origen.casa;
      _punto = r.punto;
      _direccion = r.direccion.isEmpty ? 'Mi casa' : r.direccion;
    });
  }

  void _pedirEn(Lavanderia lav) {
    context.push(
      '/cliente/nuevo-pedido',
      extra: PedidoInicial(
        lavanderia: lav,
        punto: _punto,
        direccion: _direccion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(currentAppUserProvider).valueOrNull;
    final tieneCasa = u?.ubicacionLat != null && u?.ubicacionLng != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Realizar pedido')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const _Paso(
            numero: 1,
            texto: '¿Dónde recogemos o desde dónde pides?',
          ),
          const SizedBox(height: 12),
          _OpcionOrigen(
            icono: Icons.my_location_rounded,
            titulo: 'Usar mi ubicación actual',
            subtitulo: 'Tomamos el punto del GPS donde estás ahora',
            elegida: _origen == _Origen.actual,
            cargando: _ubicando,
            onTap: _ubicando ? null : _elegirActual,
          ),
          const SizedBox(height: 10),
          _OpcionOrigen(
            icono: Icons.home_rounded,
            titulo: 'Mi casa',
            subtitulo: tieneCasa
                ? u!.direccion
                : 'Márcala en el mapa: "aquí es mi casa"',
            elegida: _origen == _Origen.casa,
            onTap: tieneCasa
                ? () => _elegirCasaGuardada(
                    u!.ubicacionLat!,
                    u.ubicacionLng!,
                    u.direccion,
                  )
                : _marcarCasa,
            accion: tieneCasa
                ? TextButton(
                    onPressed: _marcarCasa,
                    child: const Text('Cambiar'),
                  )
                : null,
          ),
          if (_punto != null) ...[
            const SizedBox(height: 26),
            const _Paso(
              numero: 2,
              texto: 'Elige una lavandería cerca de ese punto',
            ),
            const SizedBox(height: 12),
            _ListaCercanas(punto: _punto!, onElegir: _pedirEn),
          ],
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  final int numero;
  final String texto;
  const _Paso({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppTheme.primary,
          child: Text(
            '$numero',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _OpcionOrigen extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool elegida;
  final bool cargando;
  final VoidCallback? onTap;
  final Widget? accion;

  const _OpcionOrigen({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.elegida,
    this.cargando = false,
    this.onTap,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: elegida ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: elegida ? AppTheme.primary : Colors.black12,
              width: elegida ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: cargando
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icono, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ?accion,
              if (elegida && accion == null)
                const Icon(Icons.check_circle, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListaCercanas extends ConsumerWidget {
  final LatLng punto;
  final void Function(Lavanderia) onElegir;
  const _ListaCercanas({required this.punto, required this.onElegir});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lavs = ref.watch(lavanderiasProvider);
    return lavs.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('No se pudieron cargar las lavanderías: $e'),
      data: (lista) {
        final conKm = [
          for (final l in lista)
            if (l.lat != 0 || l.lng != 0)
              (lav: l, km: kmEntre(punto, LatLng(l.lat, l.lng))),
        ]..sort((a, b) => a.km.compareTo(b.km));
        if (conKm.isEmpty) {
          return const Text('Todavía no hay lavanderías registradas.');
        }
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: punto,
                    initialZoom: 13.5,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.losasustadores.laundry_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: punto,
                          width: 34,
                          height: 34,
                          child: const _MarcadorYo(),
                        ),
                        for (final c in conKm.take(8))
                          Marker(
                            point: LatLng(c.lav.lat, c.lav.lng),
                            width: 38,
                            height: 38,
                            child: GestureDetector(
                              onTap: () => onElegir(c.lav),
                              child: const Icon(
                                Icons.local_laundry_service,
                                color: AppTheme.primary,
                                size: 30,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < conKm.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TarjetaLavanderia(
                  lav: conKm[i].lav,
                  km: conKm[i].km,
                  masCercana: i == 0,
                  onTap: () => onElegir(conKm[i].lav),
                ).animate().fadeIn(delay: (60 * i).ms).slideY(begin: 0.08),
              ),
          ],
        );
      },
    );
  }
}

class _MarcadorYo extends StatelessWidget {
  const _MarcadorYo();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6),
        ],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 16),
    );
  }
}

class _TarjetaLavanderia extends ConsumerWidget {
  final Lavanderia lav;
  final double km;
  final bool masCercana;
  final VoidCallback onTap;
  const _TarjetaLavanderia({
    required this.lav,
    required this.km,
    required this.masCercana,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promedio = ref
        .watch(calificacionPromedioProvider(lav.id))
        .valueOrNull;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_laundry_service_outlined,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            lav.nombre,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (masCercana) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Más cerca',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${km.toStringAsFixed(1)} km',
                        if (promedio != null)
                          '★ ${promedio.toStringAsFixed(1)}',
                        lav.entregaDomicilio
                            ? 'Recojo a domicilio'
                            : 'Solo en local',
                      ].join(' · '),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
