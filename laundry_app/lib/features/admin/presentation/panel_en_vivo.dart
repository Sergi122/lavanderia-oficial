import 'package:flutter/material.dart';

import '../../shared/models/pedido.dart';

/// Resumen de los pedidos activos de la lavandería por estado.
class PanelEnVivo extends StatelessWidget {
  final List<Pedido> pedidos;
  final String nombreLavanderia;
  final double? lavLat, lavLng;
  final Widget? encima;
  const PanelEnVivo({
    super.key,
    required this.pedidos,
    required this.nombreLavanderia,
    this.lavLat,
    this.lavLng,
    this.encima,
  });

  @override
  Widget build(BuildContext context) {
    final porEstado = <EstadoPedido, int>{};
    for (final p in pedidos) {
      porEstado[p.estado] = (porEstado[p.estado] ?? 0) + 1;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombreLavanderia,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('${pedidos.length} pedidos'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in porEstado.entries)
                  Chip(label: Text('${e.key.label}: ${e.value}')),
              ],
            ),
            if (encima != null) ...[const SizedBox(height: 12), encima!],
          ],
        ),
      ),
    );
  }
}
