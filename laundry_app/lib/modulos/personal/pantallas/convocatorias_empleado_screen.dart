import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/contrato/datos/admin_empleados_repository.dart';
import '../../../core/sesion/auth_repository.dart';
import '../../../core/contrato/modelos/convocatoria.dart';

/// Convocatorias abiertas de cualquier lavandería, visibles para cualquier
/// empleado sin importar si ya está trabajando o no (puede querer cambiar).
class ConvocatoriasEmpleadoScreen extends ConsumerStatefulWidget {
  const ConvocatoriasEmpleadoScreen({super.key});

  @override
  ConsumerState<ConvocatoriasEmpleadoScreen> createState() =>
      _ConvocatoriasEmpleadoScreenState();
}

/// Puestos típicos para filtrar rápido; se compara contra el texto del puesto.
const _filtros = ['Todas', 'Lavado', 'Planchado', 'Reparto', 'Atención'];

class _ConvocatoriasEmpleadoScreenState
    extends ConsumerState<ConvocatoriasEmpleadoScreen> {
  String _busqueda = '';
  String _filtro = 'Todas';

  bool _coincide(Convocatoria c) {
    final texto = '${c.puesto} ${c.lavanderiaNombre} ${c.descripcion}'
        .toLowerCase();
    final porFiltro =
        _filtro == 'Todas' ||
        texto.contains(_filtro.toLowerCase().substring(0, 5));
    return porFiltro && texto.contains(_busqueda.toLowerCase());
  }

  Future<void> _postular(
    BuildContext context,
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
  Widget build(BuildContext context) {
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
          final visibles = convocatorias.where(_coincide).toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                onChanged: (v) => setState(() => _busqueda = v.trim()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por zona, lavandería o puesto',
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final f in _filtros)
                    ChoiceChip(
                      label: Text(f),
                      selected: _filtro == f,
                      onSelected: (_) => setState(() => _filtro = f),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (visibles.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'Ninguna convocatoria coincide con tu búsqueda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              for (final c in visibles)
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
