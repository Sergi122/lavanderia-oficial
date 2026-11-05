import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contrato/modelos/app_user.dart';
import '../sesion/auth_repository.dart';
import 'modulo.dart';

/// Pantalla /modulo: lista las pantallas del módulo que se está corriendo,
/// filtradas por el rol de la cuenta. Sirve para presentar el avance.
class MenuModuloScreen extends ConsumerWidget {
  const MenuModuloScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulos = ref.watch(modulosActivosProvider);
    final presentado = ref.watch(moduloPresentadoProvider);
    final rol =
        ref.watch(currentAppUserProvider).valueOrNull?.role ?? UserRole.cliente;
    final mostrar = presentado == null
        ? modulos
        : [presentado, ...modulos.where((m) => m != presentado)];

    return Scaffold(
      appBar: AppBar(
        title: Text(presentado?.etiqueta ?? 'Módulos de la app'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).cerrarSesion(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (presentado != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Responsable: ${presentado.responsable}\n'
                'Cuenta con rol: ${prefijoRol(rol)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          for (final m in mostrar) ..._seccion(context, m, rol),
        ],
      ),
    );
  }

  List<Widget> _seccion(BuildContext context, Modulo m, UserRole rol) {
    final propias = m.entradas.where((e) => e.roles.contains(rol)).toList();
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text(m.etiqueta, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (propias.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Este rol no tiene pantallas en este módulo. '
            'Entra con otra cuenta de prueba.',
          ),
        ),
      for (final e in propias)
        Card(
          child: ListTile(
            leading: Icon(e.icono),
            title: Text(e.titulo),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(e.rutaPara(rol)),
          ),
        ),
    ];
  }
}

/// Se muestra al abrir una pantalla de un módulo que no está en esta versión.
class FueraDelModuloScreen extends StatelessWidget {
  final String ruta;
  const FueraDelModuloScreen({super.key, required this.ruta});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Otro módulo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.extension_outlined, size: 56),
              const SizedBox(height: 12),
              const Text(
                'Esta pantalla es de otro módulo y no está incluida aquí.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(ruta, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/modulo'),
                child: const Text('Volver al menú del módulo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
