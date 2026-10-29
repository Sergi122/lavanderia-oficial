import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pantalla para lo que necesita un módulo que todavía no forma parte de la
/// primera parte del proyecto: avisa que se está trabajando en eso.
class ProximamenteScreen extends StatelessWidget {
  final String titulo;
  final String sprint;
  final bool conBarra;
  const ProximamenteScreen({
    super.key,
    required this.titulo,
    required this.sprint,
    this.conBarra = true,
  });

  @override
  Widget build(BuildContext context) {
    final cuerpo = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.construction_rounded,
              size: 64,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Estamos trabajando en esto.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('Llega con $sprint.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
    return conBarra
        ? Scaffold(
            appBar: AppBar(title: Text(titulo)),
            body: cuerpo,
          )
        : cuerpo;
  }
}
