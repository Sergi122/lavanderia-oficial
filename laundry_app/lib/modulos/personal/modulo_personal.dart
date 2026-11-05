import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/arranque/modulo.dart';
import '../../core/contrato/modelos/app_user.dart';
import '../../core/verificacion/paso_identidad.dart';
import 'pantallas/admin_empleados_screen.dart';
import 'pantallas/convocatorias_empleado_screen.dart';
import 'pantallas/mi_actividad_screen.dart';
import 'pantallas/perfil_empleado_screen.dart';
import 'pantallas/postular_empleado_screen.dart';
import 'pantallas/trabajar_screen.dart';

/// S4 · Gestión de personal y empleo (Milen).
final moduloPersonal = Modulo(
  numero: 4,
  id: 'personal',
  nombre: 'Gestión de personal y empleo',
  responsable: 'Milen Aliaga',
  rutas: [
    GoRoute(
      path: '/cliente/trabajar',
      builder: (_, _) => const TrabajarScreen(),
    ),
    GoRoute(
      path: '/cliente/postular-empleado',
      builder: (_, state) => PostularEmpleadoScreen(
        identidadInicial: state.extra as VerificacionIdentidad?,
      ),
    ),
    GoRoute(
      path: '/admin/empleados',
      builder: (_, _) => const AdminEmpleadosScreen(),
    ),
    GoRoute(
      path: '/empleado/perfil',
      builder: (_, _) => const PerfilEmpleadoScreen(),
    ),
    GoRoute(
      path: '/empleado/convocatorias',
      builder: (_, _) => const ConvocatoriasEmpleadoScreen(),
    ),
    GoRoute(
      path: '/empleado/actividad',
      builder: (_, _) => const MiActividadScreen(),
    ),
    GoRoute(
      path: '/repartidor/perfil',
      builder: (_, _) => const PerfilEmpleadoScreen(soloDatosPersonales: true),
    ),
  ],
  entradas: const [
    EntradaModulo(
      'Empleados de mi lavandería',
      '/admin/empleados',
      Icons.groups_outlined,
      {UserRole.admin},
    ),
    EntradaModulo('Quiero trabajar', '/cliente/trabajar', Icons.work_outline, {
      UserRole.cliente,
    }),
    EntradaModulo(
      'Postular como empleado',
      '/cliente/postular-empleado',
      Icons.assignment_ind_outlined,
      {UserRole.cliente},
    ),
    EntradaModulo(
      'Convocatorias',
      '/empleado/convocatorias',
      Icons.campaign_outlined,
      {UserRole.empleado},
    ),
    EntradaModulo('Mi actividad', '/empleado/actividad', Icons.timeline, {
      UserRole.empleado,
    }),
    EntradaModulo(
      'Mi perfil de empleado',
      '/empleado/perfil',
      Icons.badge_outlined,
      {UserRole.empleado},
    ),
    EntradaModulo(
      'Mis datos personales',
      '/repartidor/perfil',
      Icons.badge_outlined,
      {UserRole.repartidor},
    ),
  ],
);
