import 'package:flutter/material.dart';

import '../presentation/registrar_prendas_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/pedido_acciones.dart';
import '../models/pedido.dart';

class OrdenCard extends ConsumerWidget {
  final Pedido pedido;
  const OrdenCard({super.key, required this.pedido});

  EstadoPedido? get _siguienteEstado {
    switch (pedido.estado) {
      case EstadoPedido.recibido:
        return EstadoPedido.enProceso;
      case EstadoPedido.enProceso:
        return EstadoPedido.listo;
      case EstadoPedido.listo:
        return EstadoPedido.entregado;
      case EstadoPedido.entregado:
        return null;
    }
  }

  Color _colorEstado(EstadoPedido estado) {
    switch (estado) {
      case EstadoPedido.recibido:
        return AppTheme.secondary;
      case EstadoPedido.enProceso:
        return AppTheme.primary;
      case EstadoPedido.listo:
        return Colors.green;
      case EstadoPedido.entregado:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Con recojo a domicilio: no se empieza a lavar hasta que la ropa llegó, y
    // la entrega final la cierra el repartidor (con foto), no el empleado.
    var siguiente = _siguienteEstado;
    String? bloqueo;
    if (pedido.necesitaRepartidor) {
      if (pedido.estado == EstadoPedido.recibido &&
          !pedido.ropaLlegoALavanderia) {
        siguiente = null;
        bloqueo = 'Esperando que el repartidor traiga la ropa';
      } else if (pedido.estado == EstadoPedido.listo) {
        siguiente = null;
        bloqueo = 'Listo: el repartidor la llevará al cliente';
      }
    }
    final esperaCliente = esperaRopaDelCliente(pedido);
    if (esperaCliente) siguiente = null;
    final color = _colorEstado(pedido.estado);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pedido.resumenRopaRegular.isEmpty
                            ? '${pedido.totalPrendas} prendas'
                            : '${pedido.totalPrendas} prendas + ${pedido.resumenRopaRegular}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        pedido.tipoEntrega == TipoEntrega.recojoDomicilio
                            ? 'Recojo a domicilio · ${pedido.direccionRecojo}'
                            : 'Cliente lleva sus prendas',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    pedido.estado.label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (pedido.necesitaRepartidor) ...[
              const SizedBox(height: 8),
              Text(
                pedido.repartidorUid == null
                    ? (pedido.sinRepartidorPreocupante
                          ? '⚠ Sin repartidor hace ${pedido.minutosSinRepartidor} min'
                          : 'Buscando repartidor…')
                    : pedido.entregaCompletada
                    ? 'Repartidor: entrega completada'
                    : 'Repartidor: ${pedido.etapaReparto.label}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: pedido.repartidorUid == null
                      ? (pedido.sinRepartidorPreocupante
                            ? Colors.red
                            : Colors.orange)
                      : Colors.green,
                ),
              ),
            ],
            if (pedido.notas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notas: ${pedido.notas}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Bs ${pedido.costoTotal.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            if (bloqueo != null) ...[
              const SizedBox(height: 8),
              Text(
                bloqueo,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
            if (puedeRegistrarPrendas(pedido)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RegistrarPrendasScreen(pedido: pedido),
                    ),
                  ),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(
                    esperaCliente
                        ? 'Recibir y registrar prendas (IA)'
                        : 'Registrar prendas (IA)',
                  ),
                ),
              ),
            ],
            if (esperaCliente)
              TextButton(
                onPressed: () => recibirRopa(ref, pedido),
                child: const Text('Solo marcar como recibida'),
              ),
            if (siguiente != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => avanzarPedido(ref, pedido, siguiente!),
                  child: Text('Marcar como "${siguiente.label}"'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
