import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/contrato/modelos/pedido.dart';
import '../../../core/widgets/dashboard_widgets.dart';
import '../../../core/contrato/datos/pedido_repository.dart';
import 'comprobante_screen.dart';
import '../../../core/marcos/navegacion_cliente.dart';

enum _Periodo { tresMeses, esteAnio, todos }

extension on _Periodo {
  String get label => switch (this) {
    _Periodo.tresMeses => 'Últimos 3 meses',
    _Periodo.esteAnio => 'Este año',
    _Periodo.todos => 'Todos',
  };

  bool incluye(DateTime? f) {
    if (f == null || this == _Periodo.todos) return true;
    final hoy = DateTime.now();
    return switch (this) {
      _Periodo.tresMeses => f.isAfter(hoy.subtract(const Duration(days: 92))),
      _Periodo.esteAnio => f.year == hoy.year,
      _Periodo.todos => true,
    };
  }
}

String codigoPedido(Pedido p) =>
    'P-${p.id.length >= 5 ? p.id.substring(0, 5).toUpperCase() : p.id.toUpperCase()}';

/// WF-09 · Historial de pedidos (RF-14): pedidos anteriores con fecha,
/// lavandería, total y estado; al tocar uno se ve el detalle y el comprobante.
class HistorialPedidosScreen extends ConsumerStatefulWidget {
  const HistorialPedidosScreen({super.key});

  @override
  ConsumerState<HistorialPedidosScreen> createState() =>
      _HistorialPedidosScreenState();
}

class _HistorialPedidosScreenState
    extends ConsumerState<HistorialPedidosScreen> {
  _Periodo _periodo = _Periodo.tresMeses;

  @override
  Widget build(BuildContext context) {
    final pedidosAsync = ref.watch(misPedidosProvider);
    final fecha = DateFormat('dd/MM/yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pedidos')),
      bottomNavigationBar: const NavegacionCliente(actual: 1),
      body: pedidosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('No se pudieron cargar tus pedidos: $e')),
        data: (todos) {
          final pedidos =
              todos.where((p) => _periodo.incluye(p.creadoEn)).toList()..sort(
                (a, b) => (b.creadoEn ?? DateTime(0)).compareTo(
                  a.creadoEn ?? DateTime(0),
                ),
              );
          final gastado = pedidos
              .where((p) => p.estado == EstadoPedido.entregado)
              .fold<double>(0, (a, p) => a + p.costoTotal);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Row(
                children: [
                  DropdownButton<_Periodo>(
                    value: _periodo,
                    items: [
                      for (final p in _Periodo.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (v) => setState(() => _periodo = v ?? _periodo),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${pedidos.length} pedidos · Bs ${gastado.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (pedidos.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: EstadoVacio(
                    icono: Icons.receipt_long_outlined,
                    mensaje: 'No hay pedidos en este período.',
                  ),
                ),
              for (final p in pedidos)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppTheme.primary,
                    ),
                    title: Text('${codigoPedido(p)} · ${p.lavanderiaNombre}'),
                    subtitle: Text(
                      '${p.creadoEn == null ? '—' : fecha.format(p.creadoEn!)} · '
                      '${p.totalPrendas} prendas · ${p.estado.label}',
                    ),
                    trailing: Text(
                      'Bs ${p.costoTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => _detalle(context, p),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _detalle(BuildContext context, Pedido p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${codigoPedido(p)} · ${p.lavanderiaNombre}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {1: IntrinsicColumnWidth()},
              children: [
                const TableRow(
                  children: [
                    Text(
                      'Prenda',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Cant.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (p.cantidadRopaRegular > 0)
                  TableRow(
                    children: [
                      Text('Ropa regular (por ${p.modoRopaRegular.name})'),
                      Text(p.cantidadRopaRegular.toStringAsFixed(1)),
                    ],
                  ),
                for (final e in p.prendas.entries)
                  TableRow(children: [Text(e.key), Text('${e.value}')]),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Pagado: Bs ${p.costoTotal.toStringAsFixed(2)} · ${p.estado.label}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_outlined),
                    label: const Text('Ver comprobante'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ComprobanteScreen(pedido: p),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Repetir pedido'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/cliente/realizar-pedido');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
