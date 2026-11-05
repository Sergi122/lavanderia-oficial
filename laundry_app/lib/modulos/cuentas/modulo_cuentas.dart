import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/arranque/modulo.dart';
import '../../core/contrato/modelos/app_user.dart';
import 'pantallas/completar_perfil_screen.dart';
import 'pantallas/cuenta_suspendida_screen.dart';
import 'pantallas/login_screen.dart';
import 'pantallas/perfil_screen.dart';
import 'pantallas/splash_screen.dart';
import 'pantallas/verificar_correo_screen.dart';

/// S1 · Gestión de cuentas de usuario (Luis). Va en todas las versiones:
/// pone el inicio de sesión que usan los demás módulos.
final moduloCuentas = Modulo(
  numero: 1,
  id: 'cuentas',
  nombre: 'Gestión de cuentas de usuario',
  responsable: 'Luis Dorado',
  rutas: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: '/cuenta-suspendida',
      builder: (_, _) => const CuentaSuspendidaScreen(),
    ),
    GoRoute(
      path: '/verificar-correo',
      builder: (_, _) => const VerificarCorreoScreen(),
    ),
    GoRoute(
      path: '/cliente/completar-perfil',
      builder: (_, _) => const CompletarPerfilScreen(),
    ),
    GoRoute(path: '/cliente/perfil', builder: (_, _) => const PerfilScreen()),
  ],
  entradas: const [
    EntradaModulo('Mi perfil', '/cliente/perfil', Icons.person_outline, {
      UserRole.cliente,
      UserRole.empleado,
      UserRole.repartidor,
    }),
    EntradaModulo(
      'Completar perfil',
      '/cliente/completar-perfil',
      Icons.badge_outlined,
      {UserRole.cliente},
    ),
  ],
);
