import 'package:flutter/material.dart';

/// Un botón de los accesos rápidos del panel.
class AccionNube {
  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;
  final bool principal;
  const AccionNube(
    this.icono,
    this.etiqueta,
    this.onTap, {
    this.principal = false,
  });
}

/// Accesos rápidos del panel de la lavandería.
class NubeAcciones extends StatelessWidget {
  final List<AccionNube> acciones;
  const NubeAcciones({super.key, required this.acciones});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final a in acciones)
        a.principal
            ? FilledButton.icon(
                onPressed: a.onTap,
                icon: Icon(a.icono),
                label: Text(a.etiqueta),
              )
            : OutlinedButton.icon(
                onPressed: a.onTap,
                icon: Icon(a.icono),
                label: Text(a.etiqueta),
              ),
    ],
  );
}
