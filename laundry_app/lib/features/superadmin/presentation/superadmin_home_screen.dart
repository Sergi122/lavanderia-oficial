import 'dart:convert';

import 'package:flutter/material.dart';

import '../../shared/widgets/dashboard_widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/models/app_user.dart';
import '../../shared/models/pedido.dart';
import '../../shared/data/soporte_repository.dart';
import '../../shared/models/solicitud_lavanderia.dart';
import '../../shared/models/ticket_soporte.dart';
import '../../shared/widgets/solicitud_widgets.dart';
import '../data/superadmin_repository.dart';

class SuperadminHomeScreen extends ConsumerWidget {
  const SuperadminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        body: const Column(
          children: [
            PanelHeader(
              rol: 'CEO',
              subtitulo: 'control total de la red',
              icono: Icons.admin_panel_settings_outlined,
            ),
            PestanasPanel(
              scrollable: true,
              tabs: [
                Tab(text: 'Usuarios'),
                Tab(text: 'Locales por aprobar'),
                Tab(text: 'Lavanderías'),
                Tab(text: 'Repartidores'),
                Tab(text: 'Pedidos'),
                Tab(text: 'Soporte'),
                Tab(text: 'Métricas'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TabUsuarios(),
                  _TabLocalesPorAprobar(),
                  _TabLavanderias(),
                  _TabRepartidores(),
                  _TabPedidos(),
                  _TabSoporte(),
                  _TabMetricas(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabUsuarios extends ConsumerStatefulWidget {
  const _TabUsuarios();

  @override
  ConsumerState<_TabUsuarios> createState() => _TabUsuariosState();
}

class _TabUsuariosState extends ConsumerState<_TabUsuarios> {
  final _busquedaCtrl = TextEditingController();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirDetalle(AppUser usuario) async {
    var rolSeleccionado = usuario.role;
    await showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                usuario.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                usuario.email,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                initialValue: rolSeleccionado,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: [
                  for (final r in UserRole.values)
                    DropdownMenuItem(value: r, child: Text(r.name)),
                ],
                onChanged: (v) => setState(() => rolSeleccionado = v!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await ref
                            .read(superadminRepositoryProvider)
                            .cambiarRol(usuario.uid, rolSeleccionado);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: const Text('Guardar rol'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref
                            .read(superadminRepositoryProvider)
                            .toggleActivoUsuario(usuario.uid, !usuario.activo);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: usuario.activo
                            ? Colors.red
                            : Colors.green,
                      ),
                      child: Text(
                        usuario.activo
                            ? 'Suspender cuenta'
                            : 'Reactivar cuenta',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuariosAsync = ref.watch(todosLosUsuariosProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _busquedaCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Buscar por nombre o correo',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: usuariosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (usuarios) {
              final query = _busquedaCtrl.text.trim().toLowerCase();
              final filtrados = query.isEmpty
                  ? usuarios
                  : usuarios
                        .where(
                          (u) =>
                              u.nombre.toLowerCase().contains(query) ||
                              u.email.toLowerCase().contains(query),
                        )
                        .toList();
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final u in filtrados)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(u.nombre),
                        subtitle: Text('${u.email} · ${u.role.name}'),
                        trailing: u.activo
                            ? null
                            : const Icon(
                                Icons.block,
                                color: Colors.red,
                                size: 18,
                              ),
                        onTap: () => _abrirDetalle(u),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// Segunda etapa: el verificador ya confirmó la identidad del dueño, ahora
// el superadmin revisa el local en sí (ubicación, NIT, fotos, duplicados)
// antes de crear la lavandería pública y promoverlo a admin.
class _TabLocalesPorAprobar extends ConsumerWidget {
  const _TabLocalesPorAprobar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudesAsync = ref.watch(
      solicitudesLavanderiaParaSuperadminProvider,
    );

    return solicitudesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar solicitudes: $e')),
      data: (solicitudes) {
        if (solicitudes.isEmpty) {
          return const Center(
            child: Text(
              'No hay locales esperando revisión.',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final s in solicitudes)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _SolicitudLocalCard(solicitud: s),
              ),
          ],
        );
      },
    );
  }
}

class _SolicitudLocalCard extends ConsumerWidget {
  final SolicitudLavanderia solicitud;
  const _SolicitudLocalCard({required this.solicitud});

  Future<void> _abrirEnMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${solicitud.lat},${solicitud.lng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              solicitud.nombre,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              solicitud.nit.isEmpty
                  ? 'NIT: no registrado'
                  : 'NIT: ${solicitud.nit}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              solicitud.direccion,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final serv in solicitud.servicios)
                  Chip(
                    label: Text(serv),
                    backgroundColor: const Color(0xFFEFF6F6),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _abrirEnMaps,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ver ubicación en Google Maps'),
            ),
            BadgeDuplicado(
              posibleDuplicado: solicitud.posibleDuplicado,
              motivo: solicitud.motivoDuplicado,
            ),
            BadgeDuplicado(
              posibleDuplicado: solicitud.pruebaVidaOk == false,
              motivo: 'Prueba de vida: ${solicitud.motivoPruebaVida}',
            ),
            if (solicitud.fotosBase64.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Fotos del local',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: solicitud.fotosBase64.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(solicitud.fotosBase64[index]),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'La identidad del dueño ya fue confirmada por un verificador. '
              'Aquí revisas el local en sí antes de publicarlo.',
              style: TextStyle(
                color: Colors.black45,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final motivo = await pedirMotivoRechazo(context);
                      if (motivo == null) return;
                      await ref
                          .read(superadminRepositoryProvider)
                          .rechazarLavanderia(solicitud.propietarioUid, motivo);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(superadminRepositoryProvider)
                        .aprobarLavanderia(solicitud),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    child: const Text('Aprobar local'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLavanderias extends ConsumerWidget {
  const _TabLavanderias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lavanderiasAsync = ref.watch(todasLasLavanderiasProvider);

    return lavanderiasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (lavanderias) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final lav in lavanderias)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(lav.nombre),
                subtitle: Text(lav.direccion),
                trailing: Switch(
                  value: lav.activo,
                  onChanged: (v) => ref
                      .read(superadminRepositoryProvider)
                      .toggleActivoLavanderia(lav.id, v),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabRepartidores extends ConsumerWidget {
  const _TabRepartidores();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(todosLosUsuariosProvider);

    return usuariosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (usuarios) {
        final repartidores = usuarios
            .where((u) => u.role == UserRole.repartidor)
            .toList();
        if (repartidores.isEmpty) {
          return const Center(
            child: Text(
              'No hay repartidores todavía.',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final r in repartidores)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(r.nombre),
                  subtitle: Text('${r.email} · ${r.telefono}'),
                  trailing: Switch(
                    value: r.activo,
                    onChanged: (v) => ref
                        .read(superadminRepositoryProvider)
                        .toggleActivoUsuario(r.uid, v),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TabPedidos extends ConsumerWidget {
  const _TabPedidos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidosAsync = ref.watch(pedidosRecientesProvider);

    return pedidosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (pedidos) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Últimos 50 pedidos',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final p in pedidos)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(p.lavanderiaNombre),
                subtitle: Text(
                  '${p.estado.label} · Bs ${p.costoTotal.toStringAsFixed(0)}',
                ),
                trailing: Text(
                  p.id.substring(0, 6),
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabSoporte extends ConsumerWidget {
  const _TabSoporte();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(ticketsAbiertosProvider);

    return ticketsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tickets) {
        if (tickets.isEmpty) {
          return const Center(
            child: Text(
              'No hay tickets de soporte.',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final t in tickets)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.asunto,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              t.estado == EstadoTicket.abierto
                                  ? 'Abierto'
                                  : 'Resuelto',
                            ),
                            backgroundColor: t.estado == EstadoTicket.abierto
                                ? Colors.orange.withValues(alpha: 0.15)
                                : Colors.green.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: t.estado == EstadoTicket.abierto
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          t.autorNombre,
                          if (t.rolAutor.isNotEmpty) t.rolAutor,
                          if (t.lavanderiaNombre.isNotEmpty) t.lavanderiaNombre,
                          if (t.categoria.isNotEmpty) t.categoria,
                        ].join(' · '),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(t.mensaje),
                      if (t.respuesta.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Respuesta: ${t.respuesta}',
                          style: TextStyle(color: Colors.green.shade800),
                        ),
                      ],
                      if (t.estado == EstadoTicket.abierto) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: () async {
                              final ctrl = TextEditingController();
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Responder y resolver'),
                                  content: TextField(
                                    controller: ctrl,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Respuesta (la verá quien lo abrió)',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Resolver'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              await ref
                                  .read(soporteRepositoryProvider)
                                  .marcarResuelto(
                                    t.id,
                                    respuesta: ctrl.text.trim(),
                                  );
                            },
                            child: const Text('Responder y resolver'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TabMetricas extends ConsumerWidget {
  const _TabMetricas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricasAsync = ref.watch(metricasGlobalesProvider);

    return metricasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (m) => GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _TarjetaMetrica(titulo: 'Usuarios', valor: m.usuarios),
          _TarjetaMetrica(titulo: 'Lavanderías', valor: m.lavanderias),
          _TarjetaMetrica(titulo: 'Pedidos totales', valor: m.pedidos),
          _TarjetaMetrica(
            titulo: 'Repartidores activos',
            valor: m.repartidoresActivos,
          ),
        ],
      ),
    );
  }
}

class _TarjetaMetrica extends StatelessWidget {
  final String titulo;
  final int valor;
  const _TarjetaMetrica({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$valor',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
