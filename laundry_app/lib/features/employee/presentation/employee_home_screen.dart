import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../client/data/pedido_repository.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/data/pedido_acciones.dart';
import '../../shared/models/pedido.dart';
import '../../shared/widgets/orden_card.dart';

const _frasesMotivacionales = [
  '💪 Cada postulación te acerca más a tu próximo trabajo.',
  '🌟 Tu experiencia vale — sigue buscando, el trabajo indicado va a aparecer.',
  '🚀 Un perfil completo (foto, CV) llama mucho más la atención de los admins.',
  '☀️ Hoy puede ser el día en que un admin te contrate directo desde la bolsa.',
  '🧺 Las lavanderías siempre necesitan gente confiable — esa eres tú.',
];

class EmployeeHomeScreen extends ConsumerWidget {
  const EmployeeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final lavanderiaId = appUser?.lavanderiaId;

    return Scaffold(
      body: Column(
        children: [
          PanelHeader(
            rol: 'Empleado',
            subtitulo: lavanderiaId == null
                ? 'buscando trabajo'
                : 'cola de pedidos',
            icono: Icons.badge_outlined,
            onAvatarTap: () => context.push('/empleado/perfil'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: FilaAcciones(
              acciones: [
                AccionRapida(
                  icono: Icons.local_laundry_service_outlined,
                  etiqueta: 'Pedir lavado',
                  onTap: () => context.push('/cliente/realizar-pedido'),
                ),
                AccionRapida(
                  icono: Icons.badge_outlined,
                  etiqueta: 'Convocatorias',
                  color: AppTheme.secondary,
                  onTap: () => context.push('/empleado/convocatorias'),
                ),
                AccionRapida(
                  icono: Icons.person_outline,
                  etiqueta: 'Mi perfil',
                  color: const Color(0xFFF57C00),
                  onTap: () => context.push('/empleado/perfil'),
                ),
                AccionRapida(
                  icono: Icons.support_agent_outlined,
                  etiqueta: 'Soporte',
                  color: const Color(0xFF7B61FF),
                  onTap: () => context.push('/cliente/asistencia'),
                ),
              ],
            ),
          ),
          Expanded(child: _cuerpo(lavanderiaId)),
        ],
      ),
    );
  }

  Widget _cuerpo(String? lavanderiaId) {
    return Builder(
      builder: (context) {
        return lavanderiaId == null
            ? const _PanelSinTrabajo()
            : Consumer(
                builder: (context, ref, _) {
                  final pedidosAsync = ref.watch(
                    pedidosLavanderiaProvider(lavanderiaId),
                  );
                  return pedidosAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Center(child: Text('Error al cargar pedidos: $e')),
                    data: (pedidos) => _ColaEmpleado(pedidos: pedidos),
                  );
                },
              );
      },
    );
  }
}

enum _Filtro { porRecibir, enCola, lavando, listos, todos }

/// Cola del empleado: qué está haciendo (lo ve el admin en 3D), resumen del
/// día, filtros por etapa, búsqueda y pedidos más antiguos primero.
class _ColaEmpleado extends StatefulWidget {
  final List<Pedido> pedidos;
  const _ColaEmpleado({required this.pedidos});

  @override
  State<_ColaEmpleado> createState() => _ColaEmpleadoState();
}

class _ColaEmpleadoState extends State<_ColaEmpleado> {
  _Filtro _filtro = _Filtro.enCola;
  String _q = '';

  bool _pasa(Pedido p, [_Filtro? filtro]) => switch (filtro ?? _filtro) {
    _Filtro.porRecibir => p.estado == EstadoPedido.recibido && !p.ropaRecibida,
    _Filtro.enCola => p.estado == EstadoPedido.recibido && p.ropaRecibida,
    _Filtro.lavando => p.estado == EstadoPedido.enProceso,
    _Filtro.listos => p.estado == EstadoPedido.listo,
    _Filtro.todos => true,
  };

  @override
  Widget build(BuildContext context) {
    final todos = widget.pedidos;
    final hoy = DateTime.now();
    bool esHoy(DateTime? d) =>
        d != null &&
        d.year == hoy.year &&
        d.month == hoy.month &&
        d.day == hoy.day;
    final cuenta = {
      for (final f in _Filtro.values) f: todos.where((p) => _pasa(p, f)).length,
    };
    final q = _q.toLowerCase();
    final lista =
        todos
            .where((p) => _pasa(p))
            .where(
              (p) =>
                  q.isEmpty ||
                  p.id.toLowerCase().contains(q) ||
                  p.clienteNombre.toLowerCase().contains(q),
            )
            .toList()
          // el más antiguo primero: así nada se queda olvidado al fondo
          ..sort((a, b) => (a.creadoEn ?? hoy).compareTo(b.creadoEn ?? hoy));
    const etiquetas = {
      _Filtro.porRecibir: 'Por recibir',
      _Filtro.enCola: 'En cola',
      _Filtro.lavando: 'Lavando',
      _Filtro.listos: 'Listos',
      _Filtro.todos: 'Todos',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            _Mini(
              'Recibidos hoy',
              '${todos.where((p) => esHoy(p.ropaRecibidaEn) || (p.necesitaRepartidor && esHoy(p.creadoEn) && p.ropaRecibida)).length}',
              Icons.move_to_inbox_outlined,
            ),
            const SizedBox(width: 10),
            _Mini(
              'En máquinas',
              '${cuenta[_Filtro.lavando]}',
              Icons.local_laundry_service_outlined,
            ),
            const SizedBox(width: 10),
            _Mini(
              'Para entregar',
              '${cuenta[_Filtro.listos]}',
              Icons.check_circle_outline,
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _q = v.trim()),
          decoration: const InputDecoration(
            hintText: 'Buscar por código o cliente',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _Filtro.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${etiquetas[f]} ${cuenta[f]}'),
                    selected: _filtro == f,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filtro = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (lista.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EstadoVacio(
              icono: Icons.inbox_outlined,
              mensaje: 'Nada en esta etapa por ahora.',
            ),
          ),
        for (var i = 0; i < lista.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child:
                Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Espera(pedido: lista[i]),
                        OrdenCard(pedido: lista[i]),
                      ],
                    )
                    .animate()
                    .fadeIn(delay: (i * 60).ms, duration: 300.ms)
                    .slideX(begin: 0.05, end: 0),
          ),
      ],
    );
  }
}

class _Mini extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  const _Mini(this.titulo, this.valor, this.icono);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: AppTheme.primary, size: 20),
            const SizedBox(height: 6),
            Text(
              valor,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              titulo,
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuánto lleva esperando el pedido; en naranja si ya pasó un día.
class _Espera extends StatelessWidget {
  final Pedido pedido;
  const _Espera({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final c = pedido.creadoEn;
    if (c == null) return const SizedBox.shrink();
    final d = DateTime.now().difference(c);
    final txt = d.inMinutes < 60
        ? 'hace ${d.inMinutes} min'
        : d.inHours < 24
        ? 'hace ${d.inHours} h'
        : 'hace ${d.inDays} día${d.inDays == 1 ? '' : 's'}';
    final tarde = d.inHours >= 24 && pedido.estado != EstadoPedido.listo;
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 4),
      child: Text(
        '${esperaRopaDelCliente(pedido) ? 'Esperando que el cliente traiga la ropa · ' : ''}$txt${tarde ? ' · ¡atrasado!' : ''}',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: tarde ? FontWeight.w800 : FontWeight.w500,
          color: tarde ? Colors.deepOrange : Colors.black45,
        ),
      ),
    );
  }
}

class _PanelSinTrabajo extends StatelessWidget {
  const _PanelSinTrabajo();

  @override
  Widget build(BuildContext context) {
    final frase =
        _frasesMotivacionales[Random().nextInt(_frasesMotivacionales.length)];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            frase,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'No estás trabajando en ninguna lavandería ahora mismo. Cualquier '
            'admin puede verte en su bolsa de "empleados disponibles" y '
            'contratarte directo, o puedes revisar las convocatorias abiertas '
            'y postular.',
            style: TextStyle(color: Colors.black87),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => context.push('/empleado/perfil'),
          icon: const Icon(Icons.person_outline),
          label: const Text('Completar mi perfil'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.push('/empleado/convocatorias'),
          icon: const Icon(Icons.badge_outlined),
          label: const Text('Ver convocatorias abiertas'),
        ),
      ],
    );
  }
}
