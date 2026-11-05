import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/sesion/auth_repository.dart';
import '../../../core/contrato/modelos/app_user.dart';
import '../../../core/contrato/modelos/pedido.dart';
import '../../../core/widgets/dashboard_widgets.dart';
import '../../../core/contrato/datos/pedido_repository.dart';
import 'mapa_lavanderias_screen.dart';
import '../../../core/marcos/navegacion_cliente.dart';
import '../../../core/routing/rutas_modulos.dart';

class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final pedidosAsync = ref.watch(misPedidosProvider);

    final rol = appUser?.role ?? UserRole.cliente;
    final panelPropio = switch (rol) {
      UserRole.empleado => '/empleado',
      UserRole.repartidor => '/repartidor',
      _ => null,
    };
    final esCliente = panelPropio == null;
    final activos = (pedidosAsync.valueOrNull ?? const <Pedido>[])
        .where(
          (p) => p.estado != EstadoPedido.entregado && !p.entregaCompletada,
        )
        .length;
    final perfilCompleto = appUser?.perfilCompleto ?? true;

    return Scaffold(
      bottomNavigationBar: esCliente
          ? const NavegacionCliente(actual: 0)
          : null,
      body: Column(
        children: [
          PanelHeader(
            rol: esCliente ? 'Cliente' : 'Mis pedidos de lavado',
            subtitulo: 'tu ropa en las mejores manos',
            icono: Icons.person_outline,
            onAvatarTap: esCliente
                ? () => context.push('/cliente/perfil')
                : null,
            extras: [
              IconButton(
                onPressed: () => context.push('/cliente/notificaciones'),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
                tooltip: 'Notificaciones',
              ),
              if (panelPropio != null)
                IconButton(
                  onPressed: () => context.go(panelPropio),
                  icon: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Volver a mi panel de trabajo',
                ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(misPedidosProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  const _Titulo(
                    'Lavanderías cerca de ti',
                    'Tu ubicación, tu casa y las lavanderías de la zona',
                  ),
                  const SizedBox(height: 12),
                  const MapaLavanderiasScreen(embebido: true),
                  const SizedBox(height: 10),
                  const _Leyenda(),
                  const SizedBox(height: 22),
                  const _Titulo('¿Qué quieres hacer?', null),
                  const SizedBox(height: 12),
                  _Opcion(
                    icono: Icons.add_shopping_cart_rounded,
                    titulo: 'Realizar pedido',
                    detalle: 'Desde tu ubicación actual o desde tu casa',
                    principal: true,
                    onTap: () => context.push('/cliente/realizar-pedido'),
                  ),
                  _Opcion(
                    icono: Icons.receipt_long_rounded,
                    titulo: 'Mis pedidos',
                    detalle: activos == 0
                        ? 'No tienes pedidos en curso'
                        : '$activos en curso · toca para seguirlos',
                    insignia: activos == 0 ? null : '$activos',
                    onTap: () => context.push('/cliente/pedidos'),
                  ),
                  if (esCliente)
                    _Opcion(
                      icono: perfilCompleto
                          ? Icons.person_outline_rounded
                          : Icons.assignment_ind_outlined,
                      titulo: perfilCompleto ? 'Mi perfil' : 'Completar perfil',
                      detalle: perfilCompleto
                          ? 'Tus datos y tu casa'
                          : 'Faltan tus datos para pedir más rápido',
                      alerta: !perfilCompleto,
                      onTap: () => context.push(
                        perfilCompleto
                            ? '/cliente/perfil'
                            : '/cliente/completar-perfil',
                      ),
                    ),
                  _Opcion(
                    icono: Icons.support_agent_outlined,
                    titulo: 'Ticket de asistencia',
                    detalle: '¿Pasó algo? Cuéntanos y te respondemos',
                    onTap: () => context.push('/cliente/asistencia'),
                  ),
                  if (esCliente)
                    _Opcion(
                      icono: Icons.badge_outlined,
                      titulo: 'Trabaja con nosotros',
                      detalle: 'Empleado, repartidor o abre tu lavandería',
                      onTap: () => context.push('/cliente/trabajar'),
                    ),
                  const SizedBox(height: 18),
                  _Titulo('Tus pedidos', null, key: _clavePedidos),
                  const SizedBox(height: 12),
                  pedidosAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) =>
                        Text('No se pudieron cargar tus pedidos: $e'),
                    data: (pedidos) {
                      if (pedidos.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: EstadoVacio(
                            icono: Icons.local_laundry_service_outlined,
                            mensaje: 'Aún no tienes pedidos. ¡Crea el primero!',
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < pedidos.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PedidoCard(pedido: pedidos[i])
                                  .animate()
                                  .fadeIn(
                                    delay: (100 + i * 60).ms,
                                    duration: 300.ms,
                                  )
                                  .slideY(begin: 0.05, end: 0),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _clavePedidos = GlobalKey();

class _Titulo extends StatelessWidget {
  final String texto;
  final String? detalle;
  const _Titulo(this.texto, this.detalle, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          texto,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (detalle != null)
          Text(
            detalle!,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
      ],
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, IconData i, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, size: 16, color: c),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(AppTheme.secondary, Icons.circle, 'Estás aquí'),
        item(Colors.deepOrange, Icons.home_rounded, 'Mi casa'),
        item(AppTheme.primary, Icons.location_on, 'Lavandería (tócala)'),
      ],
    );
  }
}

/// Fila de opción del inicio: ícono, título, detalle; la principal va
/// resaltada con el color de la marca.
class _Opcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;
  final bool principal;
  final bool alerta;
  final String? insignia;

  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    this.principal = false,
    this.alerta = false,
    this.insignia,
  });

  @override
  Widget build(BuildContext context) {
    final fg = principal ? Colors.white : AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: principal ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: principal ? 4 : 0,
        shadowColor: AppTheme.primary.withValues(alpha: 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: principal
                  ? null
                  : Border.all(
                      color: alerta
                          ? Colors.deepOrange.withValues(alpha: 0.5)
                          : Colors.black12,
                    ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: principal
                        ? Colors.white.withValues(alpha: 0.18)
                        : AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icono, color: alerta ? Colors.deepOrange : fg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: principal ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        detalle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: principal
                              ? Colors.white.withValues(alpha: 0.85)
                              : (alerta ? Colors.deepOrange : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
                if (insignia != null)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      insignia!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: principal ? Colors.white : Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PedidoCard extends ConsumerWidget {
  final Pedido pedido;
  const _PedidoCard({required this.pedido});

  ({IconData icono, Color color}) _estiloEstado(EstadoPedido estado) {
    switch (estado) {
      case EstadoPedido.recibido:
        return (icono: Icons.hourglass_top_rounded, color: AppTheme.secondary);
      case EstadoPedido.enProceso:
        return (icono: Icons.local_laundry_service, color: AppTheme.primary);
      case EstadoPedido.listo:
        return (icono: Icons.check_circle, color: Colors.green);
      case EstadoPedido.entregado:
        return (icono: Icons.done_all, color: Colors.grey);
    }
  }

  Future<void> _calificar(BuildContext context, WidgetRef ref) async {
    var estrellas = 5;
    final comentarioCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Califica tu pedido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setState(() => estrellas = i),
                      icon: Icon(
                        i <= estrellas ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: comentarioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
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
      ),
    );
    if (confirmado != true) return;
    await ref
        .read(pedidoRepositoryProvider)
        .calificar(
          pedido.id,
          lavanderiaId: pedido.lavanderiaId,
          calificacionLavanderia: estrellas,
          calificacionRepartidor: pedido.repartidorUid != null
              ? estrellas
              : null,
          comentario: comentarioCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estilo = _estiloEstado(pedido.estado);
    final puedeCalificar =
        pedido.estado == EstadoPedido.entregado &&
        pedido.calificacionLavanderia == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: estilo.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(estilo.icono, color: estilo.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pedido.lavanderiaNombre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${pedido.totalPrendas} prendas · ${pedido.estado.label} · Bs ${pedido.costoTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (pedido.estado != EstadoPedido.entregado &&
                !pedido.entregaCompletada) ...[
              const SizedBox(height: 10),
              if (pedido.necesitaRepartidor && pedido.sinRepartidorPreocupante)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '⏱ Sin repartidor hace ${pedido.minutosSinRepartidor} min',
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => abrirSeguimientoPedido(context, pedido.id),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(
                    pedido.necesitaRepartidor && pedido.repartidorUid == null
                        ? 'Ver estado'
                        : 'Seguir mi pedido',
                  ),
                ),
              ),
            ],
            if (pedido.tieneComprobante &&
                (pedido.entregaCompletada ||
                    pedido.estado == EstadoPedido.entregado)) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => abrirSeguimientoPedido(context, pedido.id),
                  icon: const Icon(Icons.photo_outlined, size: 18),
                  label: const Text('Ver comprobante de entrega'),
                ),
              ),
            ],
            if (puedeCalificar) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _calificar(context, ref),
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: const Text('Calificar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
