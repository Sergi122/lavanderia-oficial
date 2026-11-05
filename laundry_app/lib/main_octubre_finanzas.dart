import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'arranque.dart';
import 'core/arranque/modulo.dart';
import 'core/contrato/modelos/app_user.dart';
import 'modulos/finanzas/modulo_finanzas.dart';
import 'modulos/pedidos_cliente/pantallas/historial_pedidos_screen.dart';
import 'modulos/reparto/pantallas/repartidor_home_screen.dart';

/// Módulo de OCTUBRE de Emanuel (Sprint 5, «Administración de finanzas»),
/// armado con el código nuevo: S5 Finanzas completo (ingresos, egresos,
/// planilla, balance, informe PDF) + el comprobante digital (se abre desde
/// «Mis pedidos», hoy S6) + las ganancias del repartidor (panel del
/// repartidor, hoy S7).
/// Correr: flutter run -d chrome -t lib/main_octubre_finanzas.dart
final _octubre = Modulo(
  numero: 5,
  id: 'finanzas_octubre',
  nombre: 'Administración de finanzas (octubre)',
  responsable: 'Emanuel Velasco',
  rutas: [
    ...moduloFinanzas.rutas,
    GoRoute(
      path: '/cliente/pedidos',
      builder: (_, _) => const HistorialPedidosScreen(),
    ),
    GoRoute(
      path: '/repartidor',
      builder: (_, _) => const RepartidorHomeScreen(),
    ),
  ],
  entradas: [
    ...moduloFinanzas.entradas,
    const EntradaModulo(
      'Comprobante digital (desde Mis pedidos)',
      '/cliente/pedidos',
      Icons.receipt_outlined,
      {UserRole.cliente, UserRole.empleado, UserRole.repartidor},
    ),
    const EntradaModulo(
      'Ganancias del repartidor',
      '/repartidor',
      Icons.savings_outlined,
      {UserRole.repartidor},
    ),
  ],
);

Future<void> main() => arrancarApp([_octubre], presentado: _octubre);
