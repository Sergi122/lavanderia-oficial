import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/arranque/modulo.dart';
import '../../core/contrato/modelos/app_user.dart';
import '../../core/contrato/modelos/lavanderia.dart';
import 'pantallas/historial_pedidos_screen.dart';
import 'pantallas/notificaciones_screen.dart';
import 'pantallas/nuevo_pedido_screen.dart';
import 'pantallas/realizar_pedido_screen.dart';
import 'pantallas/seguimiento_pedido_screen.dart';

const _clientes = {UserRole.cliente, UserRole.empleado, UserRole.repartidor};

/// S6 · Gestión de pedidos del cliente (Sergio).
final moduloPedidosCliente = Modulo(
  numero: 6,
  id: 'pedidos_cliente',
  nombre: 'Gestión de pedidos del cliente',
  responsable: 'Sergio Poma',
  rutas: [
    GoRoute(
      path: '/cliente/nuevo-pedido',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is PedidoInicial) {
          return NuevoPedidoScreen(
            lavanderia: extra.lavanderia,
            puntoInicial: extra.punto,
            direccionInicial: extra.direccion,
          );
        }
        return NuevoPedidoScreen(lavanderia: extra as Lavanderia);
      },
    ),
    GoRoute(
      path: '/cliente/realizar-pedido',
      builder: (_, _) => const RealizarPedidoScreen(),
    ),
    GoRoute(
      path: '/cliente/pedidos',
      builder: (_, _) => const HistorialPedidosScreen(),
    ),
    GoRoute(
      path: '/cliente/notificaciones',
      builder: (_, _) => const NotificacionesScreen(),
    ),
    GoRoute(
      path: '/cliente/seguimiento/:id',
      builder: (_, state) =>
          SeguimientoPedidoScreen(pedidoId: state.pathParameters['id']!),
    ),
  ],
  entradas: const [
    EntradaModulo(
      'Realizar pedido',
      '/cliente/realizar-pedido',
      Icons.local_laundry_service_outlined,
      _clientes,
    ),
    EntradaModulo(
      'Mis pedidos',
      '/cliente/pedidos',
      Icons.receipt_long_outlined,
      _clientes,
    ),
    EntradaModulo(
      'Notificaciones',
      '/cliente/notificaciones',
      Icons.notifications_outlined,
      _clientes,
    ),
  ],
);
