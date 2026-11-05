import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Barra inferior del cliente de los wireframes: Inicio · Pedidos · Soporte · Perfil.
class NavegacionCliente extends StatelessWidget {
  final int actual;
  const NavegacionCliente({super.key, required this.actual});

  static const _rutas = [
    '/cliente',
    '/cliente/pedidos',
    '/cliente/asistencia',
    '/cliente/perfil',
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: actual,
      height: 64,
      onDestinationSelected: (i) {
        if (i == actual) return;
        if (i == 0) {
          context.go('/cliente');
        } else {
          context.push(_rutas[i]);
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'Pedidos',
        ),
        NavigationDestination(
          icon: Icon(Icons.support_agent_outlined),
          selectedIcon: Icon(Icons.support_agent_rounded),
          label: 'Soporte',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Perfil',
        ),
      ],
    );
  }
}
