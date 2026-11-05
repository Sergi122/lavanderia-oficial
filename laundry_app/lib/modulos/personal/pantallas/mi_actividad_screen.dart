import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/contrato/modelos/actividades.dart';
import '../../../core/sesion/auth_repository.dart';

/// WF-15 · Mi actividad (RF-26): el empleado marca qué está haciendo. También
/// cambia sola al avanzar un pedido, y el dueño la ve en vivo en la ciudad 3D.
class MiActividadScreen extends ConsumerWidget {
  const MiActividadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(currentAppUserProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi actividad')),
      body: u == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                const Text(
                  '¿Qué estás haciendo ahora?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                const SizedBox(height: 6),
                Text(
                  u.actividadEn == null
                      ? 'Cambia sola cuando avanzas un pedido.'
                      : 'Desde las ${DateFormat('HH:mm').format(u.actividadEn!)} · cambia sola cuando avanzas un pedido.',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 10),
                RadioGroup<String>(
                  groupValue: u.actividad,
                  onChanged: (v) {
                    if (v != null)
                      ref
                          .read(authRepositoryProvider)
                          .cambiarActividad(u.uid, v);
                  },
                  child: Column(
                    children: [
                      for (final e in actividades.entries)
                        RadioListTile<String>(
                          value: e.key,
                          secondary: Icon(e.value.$1, color: AppTheme.primary),
                          title: Text(e.value.$2),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
