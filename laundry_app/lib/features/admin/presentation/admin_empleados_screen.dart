import '../../../core/widgets/flotante.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../shared/models/app_user.dart';
import '../../shared/models/convocatoria.dart';
import '../../shared/models/solicitud_empleado.dart';
import '../../shared/widgets/solicitud_widgets.dart';
import '../data/admin_empleados_repository.dart';

class AdminEmpleadosScreen extends ConsumerWidget {
  const AdminEmpleadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final lavanderiaId = appUser?.lavanderiaId;

    if (lavanderiaId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Empleados')),
        body: const Center(
          child: Text('Tu cuenta no tiene una lavandería asignada.'),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Empleados'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Mi equipo'),
              Tab(text: 'Postulantes'),
              Tab(text: 'Disponibles'),
              Tab(text: 'Convocatorias'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TabMiEquipo(lavanderiaId: lavanderiaId),
            _TabPostulantes(lavanderiaId: lavanderiaId),
            _TabDisponibles(lavanderiaId: lavanderiaId),
            _TabConvocatorias(
              lavanderiaId: lavanderiaId,
              lavanderiaNombre: appUser?.nombre ?? '',
            ),
          ],
        ),
      ),
    );
  }
}

class _TabMiEquipo extends ConsumerWidget {
  final String lavanderiaId;
  const _TabMiEquipo({required this.lavanderiaId});

  Future<void> _editarSalario(
    BuildContext context,
    WidgetRef ref,
    AppUser empleado,
  ) async {
    final salarioCtrl = TextEditingController(
      text: empleado.salarioEmpleado?.toStringAsFixed(0) ?? '',
    );
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Salario de ${empleado.nombre}'),
        content: TextField(
          controller: salarioCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Salario mensual (Bs)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    final salario = double.tryParse(salarioCtrl.text.trim()) ?? 0;
    await ref
        .read(adminEmpleadosRepositoryProvider)
        .actualizarSalario(empleado.uid, salario);
  }

  Future<void> _confirmarDespido(
    BuildContext context,
    WidgetRef ref,
    AppUser empleado,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Despedir empleado?'),
        content: Text(
          '${empleado.nombre} quedará sin trabajo. Podrá aparecer en la bolsa de disponibles para otras lavanderías.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Despedir'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await ref.read(adminEmpleadosRepositoryProvider).despedir(empleado.uid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipoAsync = ref.watch(equipoActualProvider(lavanderiaId));
    return equipoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (equipo) {
        if (equipo.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavía no tienes empleados. Revisa "Postulantes", "Disponibles" '
                'o publica una convocatoria.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
          );
        }
        final planilla = equipo.fold(
          0.0,
          (a, e) => a + (e.salarioEmpleado ?? 0),
        );
        final sinSalario = equipo
            .where((e) => e.salarioEmpleado == null)
            .length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _ResumenEquipo(
                    icono: Icons.groups_rounded,
                    valor: '${equipo.length}',
                    etiqueta: 'Empleados',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResumenEquipo(
                    icono: Icons.payments_outlined,
                    valor: 'Bs ${planilla.toStringAsFixed(0)}',
                    etiqueta: 'Planilla mensual',
                  ),
                ),
              ],
            ),
            if (sinSalario > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⚠ $sinSalario empleado${sinSalario == 1 ? '' : 's'} sin salario definido: la planilla está incompleta.',
                  style: const TextStyle(color: Colors.orange, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 12),
            for (var i = 0; i < equipo.length; i++)
              _TarjetaEmpleado(
                    empleado: equipo[i],
                    onSalario: () => _editarSalario(context, ref, equipo[i]),
                    onDespedir: () =>
                        _confirmarDespido(context, ref, equipo[i]),
                  )
                  .animate()
                  .fadeIn(delay: (i * 60).ms, duration: 300.ms)
                  .slideY(begin: .06, end: 0),
          ],
        );
      },
    );
  }
}

class _TabPostulantes extends ConsumerWidget {
  final String lavanderiaId;
  const _TabPostulantes({required this.lavanderiaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudesAsync = ref.watch(
      solicitudesEmpleadoPendientesProvider(lavanderiaId),
    );
    return solicitudesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar solicitudes: $e')),
      data: (solicitudes) {
        if (solicitudes.isEmpty) {
          return const Center(
            child: Text(
              'No hay postulantes pendientes.',
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
                child: _SolicitudEmpleadoCard(solicitud: s),
              ),
          ],
        );
      },
    );
  }
}

class _SolicitudEmpleadoCard extends ConsumerWidget {
  final SolicitudEmpleado solicitud;
  const _SolicitudEmpleadoCard({required this.solicitud});

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
              'CI: ${solicitud.ci} · Edad: ${solicitud.edad} · Cel: ${solicitud.telefono}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Vive en: ${solicitud.direccion}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            if (solicitud.cvNombre.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CV: ${solicitud.cvNombre}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            const Text(
              'Carnet del postulante',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            FotosCarnet(
              anversoBase64: solicitud.carnetAnversoBase64,
              reversoBase64: solicitud.carnetReversoBase64,
            ),
            const SizedBox(height: 14),
            const Text(
              'Selfies de verificación (compara con el carnet)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            FotosSelfies(
              frenteBase64: solicitud.selfieFrenteBase64,
              izquierdaBase64: solicitud.selfieIzquierdaBase64,
              derechaBase64: solicitud.selfieDerechaBase64,
            ),
            const SizedBox(height: 10),
            BadgeVerificacionAutomatica(
              distancia: solicitud.verificacionAutomaticaDistancia,
              coincide: solicitud.verificacionAutomaticaCoincide,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final motivo = await pedirMotivoRechazo(context);
                      if (motivo == null) return;
                      await ref
                          .read(adminEmpleadosRepositoryProvider)
                          .rechazar(solicitud.uid, motivo);
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
                        .read(adminEmpleadosRepositoryProvider)
                        .aprobar(solicitud),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    child: const Text('Aprobar'),
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

class _TabDisponibles extends ConsumerWidget {
  final String lavanderiaId;
  const _TabDisponibles({required this.lavanderiaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disponiblesAsync = ref.watch(empleadosDisponiblesProvider);
    return disponiblesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (empleados) {
        if (empleados.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay empleados buscando trabajo por ahora.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final e in empleados)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primary.withValues(
                              alpha: 0.15,
                            ),
                            child: Text(
                              e.nombre.isNotEmpty
                                  ? e.nombre[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  e.telefono.isEmpty ? e.email : e.telefono,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (e.bioEmpleado.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(e.bioEmpleado),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                          ),
                          onPressed: () => ref
                              .read(adminEmpleadosRepositoryProvider)
                              .contratarDisponible(e.uid, lavanderiaId),
                          child: const Text('Contratar'),
                        ),
                      ),
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

class _TabConvocatorias extends ConsumerWidget {
  final String lavanderiaId;
  final String lavanderiaNombre;
  const _TabConvocatorias({
    required this.lavanderiaId,
    required this.lavanderiaNombre,
  });

  Future<void> _nuevaConvocatoria(BuildContext context, WidgetRef ref) async {
    final puestoCtrl = TextEditingController();
    final salarioCtrl = TextEditingController();
    final horarioCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva convocatoria'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: puestoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Puesto (ej: Empleado de lavado)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salarioCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Salario ofrecido (Bs/mes)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: horarioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Horario (ej: Lun-Sáb 8:00-17:00)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descripcionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción del puesto',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    if (puestoCtrl.text.trim().isEmpty) return;

    await ref
        .read(adminEmpleadosRepositoryProvider)
        .publicarConvocatoria(
          lavanderiaId: lavanderiaId,
          lavanderiaNombre: lavanderiaNombre,
          puesto: puestoCtrl.text.trim(),
          salario: double.tryParse(salarioCtrl.text.trim()) ?? 0,
          horario: horarioCtrl.text.trim(),
          descripcion: descripcionCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convocatoriasAsync = ref.watch(
      convocatoriasDeLavanderiaProvider(lavanderiaId),
    );
    return Scaffold(
      body: convocatoriasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (convocatorias) {
          if (convocatorias.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No has publicado convocatorias todavía. Usa el botón + para ofrecer un puesto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final c in convocatorias)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ConvocatoriaCard(convocatoria: c),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nuevaConvocatoria(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Convocatoria'),
      ),
    );
  }
}

class _ConvocatoriaCard extends ConsumerWidget {
  final Convocatoria convocatoria;
  const _ConvocatoriaCard({required this.convocatoria});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postulantesAsync = ref.watch(
      postulantesDeConvocatoriaProvider(convocatoria.id),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    convocatoria.puesto,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(convocatoria.abierta ? 'Abierta' : 'Cerrada'),
                  backgroundColor: convocatoria.abierta
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.black12,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: convocatoria.abierta
                        ? Colors.green.shade800
                        : Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Bs ${convocatoria.salario.toStringAsFixed(0)}/mes · ${convocatoria.horario}',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (convocatoria.descripcion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(convocatoria.descripcion),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const Text(
              'Postulantes',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            postulantesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (postulantes) {
                if (postulantes.isEmpty) {
                  return const Text(
                    'Nadie ha postulado todavía.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  );
                }
                return Column(
                  children: [
                    for (final p in postulantes)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.nombre),
                        subtitle: Text(
                          p.telefono.isEmpty
                              ? p.mensaje
                              : '${p.telefono} · ${p.mensaje}',
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                          ),
                          onPressed: () => ref
                              .read(adminEmpleadosRepositoryProvider)
                              .contratarDisponible(
                                p.uid,
                                convocatoria.lavanderiaId,
                              ),
                          child: const Text('Contratar'),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (convocatoria.abierta) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => ref
                      .read(adminEmpleadosRepositoryProvider)
                      .cerrarConvocatoria(convocatoria.id),
                  child: const Text('Cerrar convocatoria'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResumenEquipo extends StatelessWidget {
  final IconData icono;
  final String valor, etiqueta;
  const _ResumenEquipo({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0B2A4A), Color(0xFF1E5FB8)],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Icon(icono, color: const Color(0xFF8FD7FF)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  valor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                etiqueta,
                style: const TextStyle(color: Colors.white60, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Una tarjeta por empleado: quién es, cómo contactarlo, cuánto gana y qué se puede hacer.
class _TarjetaEmpleado extends StatelessWidget {
  final AppUser empleado;
  final VoidCallback onSalario, onDespedir;
  const _TarjetaEmpleado({
    required this.empleado,
    required this.onSalario,
    required this.onDespedir,
  });

  @override
  Widget build(BuildContext context) => Flotante(child: _contenido(context));

  Widget _contenido(BuildContext context) {
    final e = empleado;
    final foto = e.fotoBase64;
    final inicial = e.nombre.trim().isEmpty
        ? '?'
        : e.nombre.trim()[0].toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                backgroundImage: foto.isEmpty
                    ? null
                    : MemoryImage(base64Decode(foto)),
                child: foto.isEmpty
                    ? Text(
                        inicial,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.nombre,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1FA67A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Empleado activo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1FA67A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'salario' ? onSalario() : onDespedir(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'salario',
                    child: Text('Definir salario'),
                  ),
                  PopupMenuItem(value: 'despedir', child: Text('Despedir')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Dato(
            icono: Icons.payments_outlined,
            texto: e.salarioEmpleado == null
                ? 'Sin salario definido'
                : 'Bs ${e.salarioEmpleado!.toStringAsFixed(0)} al mes',
            destacado: e.salarioEmpleado != null,
          ),
          if (e.telefono.isNotEmpty)
            _Dato(icono: Icons.phone_outlined, texto: e.telefono),
          if (e.email.isNotEmpty)
            _Dato(icono: Icons.mail_outline, texto: e.email),
          if (e.direccion.isNotEmpty)
            _Dato(icono: Icons.home_outlined, texto: e.direccion),
          const SizedBox(height: 10),
          Row(
            children: [
              if (e.telefono.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:${e.telefono}')),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Llamar'),
                  ),
                ),
              if (e.telefono.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onSalario,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Salario'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool destacado;
  const _Dato({
    required this.icono,
    required this.texto,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icono, size: 17, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: destacado ? FontWeight.w800 : FontWeight.w500,
              color: destacado ? AppTheme.tinta : Colors.black87,
            ),
          ),
        ),
      ],
    ),
  );
}
