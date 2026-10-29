import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../admin/data/admin_empleados_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../shared/models/convocatoria.dart';

/// Convocatorias abiertas de cualquier lavandería, visibles para cualquier
/// empleado sin importar si ya está trabajando o no (puede querer cambiar).
class ConvocatoriasEmpleadoScreen extends ConsumerWidget {
  const ConvocatoriasEmpleadoScreen({super.key});

  Future<void> _postular(
    BuildContext context,
    WidgetRef ref,
    Convocatoria c,
    String uid,
    String nombre,
    String telefono,
  ) async {
    final mensajeCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Postular a ${c.puesto}'),
        content: TextField(
          controller: mensajeCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Mensaje para el admin (opcional)',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Postular'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await ref
        .read(adminEmpleadosRepositoryProvider)
        .postular(c.id, uid, nombre, telefono, mensajeCtrl.text.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('¡Postulación enviada!')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final convocatoriasAsync = ref.watch(convocatoriasAbiertasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Convocatorias abiertas')),
      body: convocatoriasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (convocatorias) {
          if (convocatorias.isEmpty) {
            return const Center(
              child: Text(
                'No hay convocatorias abiertas por ahora.',
                style: TextStyle(color: Colors.black54),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final c in convocatorias)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.puesto,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.lavanderiaNombre,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bs ${c.salario.toStringAsFixed(0)}/mes · ${c.horario}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (c.descripcion.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(c.descripcion),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: appUser == null
                                ? null
                                : () => _postular(
                                    context,
                                    ref,
                                    c,
                                    appUser.uid,
                                    appUser.nombre,
                                    appUser.telefono,
                                  ),
                            child: const Text('Postular'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
