import '../../../core/widgets/flotante.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../client/data/lavanderia_repository.dart';
import '../../client/data/pedido_repository.dart';
import '../../shared/data/soporte_repository.dart';
import '../../shared/models/lavanderia.dart';
import '../../shared/models/pedido.dart';
import '../../shared/models/tema_panel.dart';
import '../../shared/widgets/orden_card.dart';
import '../../client/presentation/nube_acciones.dart';
import 'admin_ciudad_screen.dart';
import 'panel_en_vivo.dart';

/// Si el navegador no puede con la ciudad 3D, se vuelve al panel clásico.
final _sinCiudad3DProvider = StateProvider<bool>((ref) => false);

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final lavanderiaId = appUser?.lavanderiaId;

    return Scaffold(
      body: lavanderiaId == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tu cuenta de administrador no tiene una lavandería asignada.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Consumer(
              builder: (context, ref, _) {
                final lavanderiaAsync = ref.watch(
                  lavanderiaPorIdProvider(lavanderiaId),
                );
                return lavanderiaAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Error al cargar tu lavandería: $e')),
                  data: (lavanderia) => lavanderia == null
                      ? const Center(
                          child: Text('No se encontró tu lavandería.'),
                        )
                      : (kIsWeb && !ref.watch(_sinCiudad3DProvider))
                      ? AdminCiudadScreen(
                          lavanderia: lavanderia,
                          onSinWebGL: () =>
                              ref.read(_sinCiudad3DProvider.notifier).state =
                                  true,
                        )
                      : _PanelAdmin(lavanderia: lavanderia),
                );
              },
            ),
    );
  }
}

class _PanelAdmin extends ConsumerWidget {
  final Lavanderia lavanderia;
  const _PanelAdmin({required this.lavanderia});

  Future<void> _contactarCeo(
    BuildContext context,
    WidgetRef ref,
    String nombreAdmin,
  ) async {
    final asuntoCtrl = TextEditingController();
    final mensajeCtrl = TextEditingController();
    final enviado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contactar al CEO'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: asuntoCtrl,
              decoration: const InputDecoration(labelText: 'Asunto'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mensajeCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Cuéntanos qué pasó',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (enviado != true) return;
    if (asuntoCtrl.text.trim().isEmpty || mensajeCtrl.text.trim().isEmpty)
      return;

    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    await ref
        .read(soporteRepositoryProvider)
        .crearTicket(
          autorUid: uid,
          autorNombre: nombreAdmin,
          lavanderiaId: lavanderia.id,
          lavanderiaNombre: lavanderia.nombre,
          asunto: asuntoCtrl.text.trim(),
          mensaje: mensajeCtrl.text.trim(),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensaje enviado al CEO. Te responderán pronto.'),
        ),
      );
    }
  }

  Future<void> _abrirEnMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${lavanderia.lat},${lavanderia.lng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _nube(BuildContext context, WidgetRef ref, String nombre) =>
      NubeAcciones(
        acciones: [
          AccionNube(
            Icons.bar_chart_rounded,
            'Finanzas',
            () => context.push('/admin/finanzas'),
            principal: true,
          ),
          AccionNube(
            Icons.badge_outlined,
            'Empleados',
            () => context.push('/admin/empleados'),
          ),
          AccionNube(
            Icons.edit_outlined,
            'Editar',
            () => context.push('/admin/editar'),
          ),
          AccionNube(
            Icons.support_agent_outlined,
            'Contacto',
            () => _contactarCeo(context, ref, nombre),
          ),
        ],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final pedidosAsync = ref.watch(pedidosLavanderiaProvider(lavanderia.id));
    final calificacionesAsync = ref.watch(
      calificacionesProvider(lavanderia.id),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pedidosLavanderiaProvider(lavanderia.id));
        ref.invalidate(calificacionesProvider(lavanderia.id));
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: AppTheme.primary,
            actions: [
              IconButton(
                onPressed: () =>
                    ref.read(authRepositoryProvider).cerrarSesion(),
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Cerrar sesión',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: 16,
                bottom: 14,
                right: 16,
              ),
              title: Text(
                lavanderia.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientePanel(lavanderia.temaPanel),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Opacity(
                      opacity: 0.25,
                      child: Text(
                        lavanderia.iconoPanel,
                        style: const TextStyle(fontSize: 130),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                pedidosAsync.when(
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (pedidos) => PanelEnVivo(
                    lavLat: lavanderia.lat,
                    lavLng: lavanderia.lng,
                    encima: _nube(context, ref, appUser?.nombre ?? 'Admin'),
                    pedidos: pedidos,
                    nombreLavanderia: lavanderia.nombre,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 24),
                if (lavanderia.descripcion.isNotEmpty ||
                    !lavanderia.horarioAtencion.estaVacio)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (lavanderia.descripcion.isNotEmpty)
                          Text(
                            lavanderia.descripcion,
                            style: const TextStyle(
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        if (!lavanderia.horarioAtencion.estaVacio) ...[
                          if (lavanderia.descripcion.isNotEmpty)
                            const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 16,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                lavanderia.horarioAtencion.formatoLegible,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => context.push('/admin/editar'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text(
                      'Agrega una descripción y tu horario de atención',
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Ubicación',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _abrirEnMaps,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 150,
                      child: IgnorePointer(
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              lavanderia.lat,
                              lavanderia.lng,
                            ),
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.losasustadores.laundry_app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(lavanderia.lat, lavanderia.lng),
                                  width: 36,
                                  height: 36,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: AppTheme.primary,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (lavanderia.servicios.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in lavanderia.servicios)
                        Chip(
                          label: Text(s),
                          backgroundColor: const Color(0xFFEFF6F6),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Pedidos actuales',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                pedidosAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Error al cargar pedidos: $e')),
                  data: (pedidos) {
                    final activos = pedidos
                        .where((p) => p.estado != EstadoPedido.entregado)
                        .toList();
                    if (activos.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No hay pedidos activos ahora mismo.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < activos.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child:
                                Flotante(child: OrdenCard(pedido: activos[i]))
                                    .animate()
                                    .fadeIn(
                                      delay: (i * 80).ms,
                                      duration: 350.ms,
                                    )
                                    .slideX(begin: 0.06, end: 0),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Reseñas de clientes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                calificacionesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Error al cargar reseñas: $e')),
                  data: (calificaciones) {
                    if (calificaciones.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Todavía no tienes reseñas de clientes.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final c in calificaciones)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      for (var i = 0; i < 5; i++)
                                        Icon(
                                          i < c.estrellas
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                  if (c.comentario.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(c.comentario),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
