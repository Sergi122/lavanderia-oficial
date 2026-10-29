import 'package:flutter/material.dart';

import '../../../core/widgets/proximamente.dart';
import '../models/lavanderia.dart';
import '../models/pedido.dart';

/// Registrar prendas con foto e IA llega con la parte 2 de Gestión de pedidos.
class RegistrarPrendasScreen extends StatelessWidget {
  final Pedido? pedido;
  final Lavanderia? lavanderia;
  const RegistrarPrendasScreen({super.key, this.pedido, this.lavanderia});

  @override
  Widget build(BuildContext context) => const ProximamenteScreen(
    titulo: 'Registrar prendas con IA',
    sprint: 'la parte 2 de Gestión de pedidos',
  );
}
