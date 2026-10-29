import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pedido.dart';

/// Tarjeta de un pedido en el panel de la lavandería. Los botones para
/// avanzar el pedido llegan con la parte 2 de Gestión de pedidos.
class OrdenCard extends ConsumerWidget {
  final Pedido pedido;
  const OrdenCard({super.key, required this.pedido});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.local_laundry_service_outlined),
    title: Text(
      pedido.clienteNombre.isEmpty ? 'Cliente' : pedido.clienteNombre,
    ),
    subtitle: Text(pedido.estado.label),
    trailing: Text(
      'Bs ${(pedido.costoPrendas + pedido.costoEnvio).toStringAsFixed(2)}',
    ),
  );
}
