import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/arranque/modulo.dart';
import '../../core/contrato/modelos/app_user.dart';
import 'pantallas/finanzas_screen.dart';

/// S5 · Control de finanzas (Emanuel).
final moduloFinanzas = Modulo(
  numero: 5,
  id: 'finanzas',
  nombre: 'Control de finanzas',
  responsable: 'Emanuel Velasco',
  rutas: [
    GoRoute(path: '/admin/finanzas', builder: (_, _) => const FinanzasScreen()),
  ],
  entradas: const [
    EntradaModulo(
      'Finanzas de la lavandería',
      '/admin/finanzas',
      Icons.payments_outlined,
      {UserRole.admin},
    ),
  ],
);
