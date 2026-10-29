import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../shared/models/pedido.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../data/repartidor_repository.dart';
import 'entregas_en_curso.dart';
import 'ruta_encargo_screen.dart';

class RepartidorHomeScreen extends ConsumerWidget {
  const RepartidorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historial =
        ref.watch(historialEntregasProvider).valueOrNull ?? const [];
    // ¡Nuevo encargo!: aviso grande al aparecer un pedido disponible.
    ref.listen(pedidosDisponiblesProvider, (antes, ahora) {
      final previos = antes?.valueOrNull?.map((p) => p.id).toSet();
      final lista = ahora.valueOrNull;
      if (previos == null || lista == null) return;
      final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
      final nuevos = lista
          .where((p) => !previos.contains(p.id) && p.clienteId != uid)
          .toList();
      if (nuevos.isEmpty || !context.mounted) return;
      _avisarNuevo(context, ref, nuevos.first);
    });
    final ganancias = historial.fold(0.0, (a, p) => a + p.costoEnvio);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            PanelHeader(
              rol: 'Repartidor',
              subtitulo: 'elige los encargos que te convienen',
              icono: Icons.two_wheeler,
              onAvatarTap: () => context.push('/repartidor/perfil'),
              contenidoInferior: Row(
                children: [
                  Expanded(
                    child: DatoHeader(
                      valor: 'Bs ${ganancias.toStringAsFixed(0)}',
                      etiqueta: 'Ganado',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DatoHeader(
                      valor: '${historial.length}',
                      etiqueta: 'Entregas',
                    ),
                  ),
                ],
              ),
            ),
            const PestanasPanel(
              tabs: [
                Tab(text: 'Disponibles'),
                Tab(text: 'En curso'),
                Tab(text: 'Historial'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FilaAcciones(
                acciones: [
                  AccionRapida(
                    icono: Icons.local_laundry_service_outlined,
                    etiqueta: 'Pedir lavado',
                    onTap: () => context.push('/cliente/realizar-pedido'),
                  ),
                  AccionRapida(
                    icono: Icons.receipt_long_outlined,
                    etiqueta: 'Mis pedidos',
                    color: AppTheme.secondary,
                    onTap: () => context.push('/cliente'),
                  ),
                  AccionRapida(
                    icono: Icons.person_outline,
                    etiqueta: 'Mi perfil',
                    color: const Color(0xFFF57C00),
                    onTap: () => context.push('/repartidor/perfil'),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _TabDisponibles(),
                  TabEntregasEnCurso(),
                  _TabHistorial(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _aceptarEncargo(
  BuildContext context,
  WidgetRef ref,
  Pedido pedido,
) async {
  try {
    final yo = ref.read(currentAppUserProvider).valueOrNull;
    await ref
        .read(repartidorRepositoryProvider)
        .aceptarPedido(
          pedido.id,
          nombre: yo?.nombre ?? '',
          telefono: yo?.telefono ?? '',
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Encargo aceptado! Revísalo en "En curso".'),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alguien más ya tomó este encargo.')),
      );
    }
  }
}

void _avisarNuevo(BuildContext context, WidgetRef ref, Pedido p) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.two_wheeler,
                      color: AppTheme.primary,
                    ),
                  )
                  .animate(onPlay: (a) => a.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.12, 1.12),
                  ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '¡Nuevo encargo cerca!',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${p.lavanderiaNombre} · ${p.totalPrendas} prendas · '
            'pagan Bs ${p.costoEnvio.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          _DatosEncargo(p: p),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Después'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(c);
                    final acepto = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RutaEncargoScreen(pedido: p),
                      ),
                    );
                    if (acepto == true && context.mounted) {
                      await _aceptarEncargo(context, ref, p);
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver en el mapa'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Datos del encargo que el repartidor necesita para decidir: dónde, cuánta
/// ropa y cuánto pagan.
class _DatosEncargo extends StatelessWidget {
  final Pedido p;
  const _DatosEncargo({required this.p});

  @override
  Widget build(BuildContext context) {
    Widget fila(IconData i, String t) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 17, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fila(
          Icons.home_outlined,
          p.direccionRecojo.isEmpty
              ? 'Sin dirección escrita'
              : p.direccionRecojo,
        ),
        fila(
          Icons.checkroom_outlined,
          '${p.totalPrendas} prendas · ${resumenCarga(p.prendas, p.resumenRopaRegular)}',
        ),
        if (p.notas.isNotEmpty) fila(Icons.sticky_note_2_outlined, p.notas),
      ],
    );
  }
}

class _TabDisponibles extends ConsumerWidget {
  const _TabDisponibles();

  Future<void> _verRuta(
    BuildContext context,
    WidgetRef ref,
    Pedido pedido,
  ) async {
    final acepto = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RutaEncargoScreen(pedido: pedido)),
    );
    if (acepto == true && context.mounted)
      await _aceptarEncargo(context, ref, pedido);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final pedidosAsync = ref.watch(pedidosDisponiblesProvider);

    return pedidosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar encargos: $e')),
      data: (todos) {
        // un repartidor no puede tomar su propio pedido
        final pedidos = todos.where((p) => p.clienteId != uid).toList();
        if (pedidos.isEmpty) {
          return const EstadoVacio(
            icono: Icons.inbox_outlined,
            mensaje: 'No hay encargos disponibles por ahora.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (var i = 0; i < pedidos.length; i++)
              Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pedidos[i].lavanderiaNombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Bs ${pedidos[i].costoEnvio.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _DatosEncargo(p: pedidos[i]),
                          if (pedidos[i].sinRepartidorPreocupante)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '⏱ Espera hace ${pedidos[i].minutosSinRepartidor} min — ¡el cliente necesita a alguien!',
                                style: const TextStyle(
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _verRuta(context, ref, pedidos[i]),
                                  icon: const Icon(Icons.route),
                                  label: const Text('Ver recorrido'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _aceptarEncargo(context, ref, pedidos[i]),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text(
                                    'Aceptar',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: (i * 70).ms, duration: 350.ms)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          ],
        );
      },
    );
  }
}

class _TabHistorial extends ConsumerWidget {
  const _TabHistorial();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidosAsync = ref.watch(historialEntregasProvider);

    return pedidosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar tu historial: $e')),
      data: (pedidos) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 16),
            if (pedidos.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EstadoVacio(
                  icono: Icons.history,
                  mensaje: 'Todavía no completaste ninguna entrega.',
                ),
              )
            else
              for (final p in pedidos)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(p.lavanderiaNombre),
                    subtitle: Text(p.direccionRecojo),
                    trailing: Text(
                      '+Bs ${p.costoEnvio.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
