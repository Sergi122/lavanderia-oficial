import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/arranque/modulo.dart';
import '../../core/contrato/modelos/app_user.dart';
import 'pantallas/admin_home_screen.dart';
import 'pantallas/editar_lavanderia_screen.dart';

/// S3 · Configuración y monitoreo de la lavandería (Paulo).
final moduloLavanderia = Modulo(
  numero: 3,
  id: 'lavanderia',
  nombre: 'Configuración y monitoreo de la lavandería',
  responsable: 'Paulo Ferrufino',
  rutas: [
    GoRoute(path: '/admin', builder: (_, _) => const AdminHomeScreen()),
    GoRoute(
      path: '/admin/editar',
      builder: (_, _) => const EditarLavanderiaScreen(),
    ),
  ],
  entradas: const [
    EntradaModulo(
      'Panel de la lavandería',
      '/admin',
      Icons.dashboard_outlined,
      {UserRole.admin},
    ),
    EntradaModulo('Editar lavandería', '/admin/editar', Icons.edit_outlined, {
      UserRole.admin,
    }),
  ],
);
