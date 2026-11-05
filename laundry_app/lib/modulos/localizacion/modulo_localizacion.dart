import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/arranque/modulo.dart';
import '../../core/contrato/modelos/app_user.dart';
import 'pantallas/client_home_screen.dart';
import 'pantallas/landing_screen.dart';
import 'pantallas/mapa_lavanderias_screen.dart';
import 'pantallas/marcar_casa_screen.dart';

const _clientes = {UserRole.cliente, UserRole.empleado, UserRole.repartidor};

/// S2 · Localización de lavanderías (Sergio).
final moduloLocalizacion = Modulo(
  numero: 2,
  id: 'localizacion',
  nombre: 'Localización de lavanderías',
  responsable: 'Sergio Poma',
  rutas: [
    GoRoute(path: '/bienvenida', builder: (_, _) => const LandingScreen()),
    GoRoute(path: '/cliente', builder: (_, _) => const ClientHomeScreen()),
    GoRoute(
      path: '/cliente/mapa',
      builder: (_, _) => const MapaLavanderiasScreen(),
    ),
    GoRoute(
      path: '/cliente/marcar-casa',
      builder: (_, _) => const MarcarCasaScreen(),
    ),
  ],
  entradas: const [
    EntradaModulo(
      'Inicio del cliente',
      '/cliente',
      Icons.home_outlined,
      _clientes,
    ),
    EntradaModulo(
      'Mapa de lavanderías',
      '/cliente/mapa',
      Icons.map_outlined,
      _clientes,
    ),
    EntradaModulo(
      'Marcar mi casa',
      '/cliente/marcar-casa',
      Icons.add_location_alt_outlined,
      _clientes,
    ),
  ],
);
