import 'package:flutter/material.dart';

import 'ciudad_3d_control.dart';

/// Fuera de la web la ciudad 3D no está disponible: fondo suave en su lugar.
class Ciudad3DView extends StatelessWidget {
  final Map<String, dynamic> datos;
  final Ciudad3DControl control;
  final void Function(Seleccion3D?)? onSeleccion;
  final VoidCallback? onSinWebGL;
  const Ciudad3DView({
    super.key,
    required this.datos,
    required this.control,
    this.onSeleccion,
    this.onSinWebGL,
  });

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFEEF1FB), Color(0xFFDDE5F8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  );
}

/// En la web evita que el iframe de la ciudad se quede con los clics; fuera de
/// la web no hace falta.
class SobreCiudad3D extends StatelessWidget {
  final Widget child;
  const SobreCiudad3D({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
