import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'arranque.dart';
import 'core/arranque/modulo.dart';
import 'core/contrato/modelos/app_user.dart';
import 'core/verificacion/paso_identidad.dart';
import 'modulos/afiliacion/pantallas/abrir_lavanderia_screen.dart';
import 'modulos/lavanderia/modulo_lavanderia.dart';

/// Módulo de OCTUBRE de Paulo (Sprint 3, «Gestión de lavanderías»), armado
/// con el código nuevo: S3 completo (panel del negocio, configurar datos,
/// precios y descuentos, lavandería en 3D) + «Abrir mi lavandería», que en
/// la división de noviembre pasó a S8 Afiliación.
/// Correr: flutter run -d chrome -t lib/main_octubre_lavanderia.dart
final _octubre = Modulo(
  numero: 3,
  id: 'octubre_lavanderia',
  nombre: 'Gestión de lavanderías (octubre)',
  responsable: 'Paulo Ferrufino',
  rutas: [
    ...moduloLavanderia.rutas,
    GoRoute(
      path: '/cliente/abrir-lavanderia',
      builder: (_, state) => AbrirLavanderiaScreen(
        identidadInicial: state.extra as VerificacionIdentidad?,
      ),
    ),
  ],
  entradas: [
    const EntradaModulo(
      'Abrir mi lavandería',
      '/cliente/abrir-lavanderia',
      Icons.storefront_outlined,
      {UserRole.cliente},
    ),
    ...moduloLavanderia.entradas,
  ],
);

Future<void> main() => arrancarApp([_octubre], presentado: _octubre);
