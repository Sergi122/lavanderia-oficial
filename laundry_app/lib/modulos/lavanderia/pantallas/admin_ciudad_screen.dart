import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/contrato/modelos/actividades.dart';
import '../../../core/widgets/perfil_empleado_hoja.dart';
import '../../../core/routing/rutas_modulos.dart';
import '../../../core/sesion/auth_repository.dart';
import '../../../core/contrato/datos/lavanderia_repository.dart';
import '../../../core/contrato/datos/pedido_repository.dart';
import '../../../core/contrato/datos/intencion_pedido_repository.dart';
import '../../../core/contrato/datos/pedido_acciones.dart';
import '../../../core/contrato/datos/soporte_repository.dart';
import '../../../core/contrato/modelos/app_user.dart';
import '../../../core/contrato/modelos/intencion_pedido.dart';
import '../../../core/contrato/modelos/lavanderia.dart';
import '../../../core/contrato/modelos/pedido.dart';
import '../../../core/escena_3d/ciudad_3d.dart';
import '../../../core/escena_3d/ciudad_3d_control.dart';
import '../../../core/contrato/datos/admin_empleados_repository.dart';
import '../../../core/contrato/datos/actividad_auto.dart';

/* Paleta de los paneles flotantes (estilo WareTrack: vidrio blanco, azul). */
const _tinta = Color(0xFF0A1C33);
const _gris = Color(0xFF5B6787);
const _azul = Color(0xFF2F6FE0);

/// Actividad que el panel muestra para cada empleado (deducida de los pedidos
/// en cada build del panel; la leen el inspector y las listas).
Map<String, String> _actividadPanel = const {};
String actividadDe(AppUser e) => _actividadPanel[e.uid] ?? e.actividad;

/// Panel del admin en la web: la ciudad 3D ocupa toda la pantalla y los menús
/// flotan encima (barra superior, indicadores, riel de navegación, inspector,
/// seguimiento del pedido y lista con pestañas).
class AdminCiudadScreen extends ConsumerStatefulWidget {
  final Lavanderia lavanderia;
  final VoidCallback onSinWebGL;
  const AdminCiudadScreen({
    super.key,
    required this.lavanderia,
    required this.onSinWebGL,
  });

  @override
  ConsumerState<AdminCiudadScreen> createState() => _AdminCiudadScreenState();
}

class _AdminCiudadScreenState extends ConsumerState<AdminCiudadScreen> {
  final _control = Ciudad3DControl();
  Seleccion3D? _sel;
  String? _pedidoSeguido;
  int _pestana = 0;
  String _busqueda = '';
  // las etapas del trabajo rotan: se recalcula cada 30 s
  late final Timer _tic = Timer.periodic(
    const Duration(seconds: 30),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _tic;
  }

  @override
  void dispose() {
    _tic.cancel();
    super.dispose();
  }

  Lavanderia get lav => widget.lavanderia;

  void _elegir(Seleccion3D? s, {bool volar = false}) {
    setState(() {
      _sel = s;
      if (s?.tipo == 'pedido') _pedidoSeguido = s!.id;
    });
    if (volar && s != null) _control.enfocarObjeto(s.tipo, s.id);
  }

  Map<String, dynamic> _datos(
    List<AppUser> equipo,
    List<Pedido> pedidos,
    List<IntencionPedido> intenciones,
  ) => {
    'lavanderia': {'nombre': lav.nombre, 'lat': lav.lat, 'lng': lav.lng},
    'empleados': [
      for (final e in equipo)
        {'id': e.uid, 'nombre': e.nombre, 'actividad': actividadDe(e)},
    ],
    'pedidos': [
      for (final p in pedidos)
        if (p.estado != EstadoPedido.entregado && !p.entregaCompletada)
          {
            'id': p.id,
            'clienteId': p.clienteId,
            'cliente': p.clienteNombre,
            'estado': p.estado.name,
            'entrega': p.tipoEntrega.name,
            'etapa': p.etapaReparto.name,
            'conRepartidor': p.repartidorUid != null,
            'lat': p.recojoLat,
            'lng': p.recojoLng,
            'repLat': p.repartidorLat,
            'repLng': p.repartidorLng,
            'recibida': p.ropaRecibida,
            'recibidaPor': p.ropaRecibidaPor,
            'prendas': p.totalPrendas,
          },
    ],
    'intenciones': [for (final i in intenciones) i.toJson()],
  };

  @override
  Widget build(BuildContext context) {
    final equipo =
        ref.watch(equipoActualProvider(lav.id)).valueOrNull ??
        const <AppUser>[];
    final pedidos =
        ref.watch(pedidosLavanderiaProvider(lav.id)).valueOrNull ??
        const <Pedido>[];
    final intenciones =
        ref.watch(intencionesLavanderiaProvider(lav.id)).valueOrNull ??
        const <IntencionPedido>[];
    final activos = pedidos
        .where(
          (p) => p.estado != EstadoPedido.entregado && !p.entregaCompletada,
        )
        .toList();
    _actividadPanel = actividadesAutomaticas(equipo, activos, DateTime.now());
    final ancho = MediaQuery.sizeOf(context).width;
    final compacto = ancho < 1100;

    Pedido? seguido;
    for (final p in activos) {
      if (p.id == _pedidoSeguido) seguido = p;
    }
    seguido ??= activos.isEmpty ? null : activos.first;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF1FB),
      body: Stack(
        children: [
          Positioned.fill(
            child: Ciudad3DView(
              datos: _datos(equipo, pedidos, intenciones),
              control: _control,
              onSeleccion: _elegir,
              onSinWebGL: widget.onSinWebGL,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: SobreCiudad3D(
              child: _BarraSuperior(
                lav: lav,
                porRecibir: activos
                    .where((p) => p.estado == EstadoPedido.recibido)
                    .toList(),
                onBuscar: (q) => setState(() => _busqueda = q),
                resultados: _busqueda.isEmpty
                    ? const []
                    : activos
                          .where(
                            (p) =>
                                p.id.toLowerCase().contains(
                                  _busqueda.toLowerCase(),
                                ) ||
                                p.clienteNombre.toLowerCase().contains(
                                  _busqueda.toLowerCase(),
                                ),
                          )
                          .take(6)
                          .toList(),
                onElegirPedido: (p) {
                  setState(() => _busqueda = '');
                  _elegir(Seleccion3D('pedido', p.id), volar: true);
                },
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 84,
            child: SobreCiudad3D(
              child: _Kpis(
                pedidos: pedidos,
                activos: activos,
                compacto: compacto,
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: compacto ? 172 : 180,
            child: SobreCiudad3D(
              child: _Riel(
                control: _control,
                onIr: (ruta) => context.push(ruta),
                onSoporte: () => _contactarSoporte(context),
                onLavanderia: () =>
                    _elegir(const Seleccion3D('lavanderia', 'lav')),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 84,
            width: compacto ? 300 : 340,
            child: SobreCiudad3D(
              child: _Inspector(
                sel: _sel ?? const Seleccion3D('lavanderia', 'lav'),
                lav: lav,
                equipo: equipo,
                pedidos: pedidos,
                intenciones: intenciones,
                onCerrar: () => setState(() => _sel = null),
                onVer: (s) => _elegir(s, volar: true),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            width: compacto ? ancho - 32 - 360 : 640,
            child: SobreCiudad3D(
              child: _Seguimiento(
                pedido: seguido,
                onTap: (p) => _elegir(Seleccion3D('pedido', p.id), volar: true),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            width: compacto ? 340 : 400,
            child: SobreCiudad3D(
              child: _ListaPestanas(
                pestana: _pestana,
                onPestana: (i) => setState(() => _pestana = i),
                activos: activos,
                equipo: equipo,
                intenciones: intenciones
                    .where((i) => i.estado == EstadoIntencion.armando)
                    .toList(),
                onElegir: (s) => _elegir(s, volar: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _contactarSoporte(BuildContext context) async {
    final asunto = TextEditingController();
    final mensaje = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ticket de soporte'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: asunto,
                decoration: const InputDecoration(labelText: 'Asunto'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mensaje,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Cuéntanos qué pasó',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (ok != true ||
        asunto.text.trim().isEmpty ||
        mensaje.text.trim().isEmpty) {
      return;
    }
    final u = ref.read(currentAppUserProvider).valueOrNull;
    await ref
        .read(soporteRepositoryProvider)
        .crearTicket(
          autorUid: u?.uid ?? '',
          autorNombre: u?.nombre ?? '',
          lavanderiaId: lav.id,
          lavanderiaNombre: lav.nombre,
          asunto: asunto.text.trim(),
          mensaje: mensaje.text.trim(),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket enviado al equipo de soporte')),
      );
    }
  }
}

/* ───────────────────────── piezas de los paneles ───────────────────────── */

class _Vidrio extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Vidrio({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _azul.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF283C78).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BarraSuperior extends ConsumerStatefulWidget {
  final Lavanderia lav;
  final List<Pedido> porRecibir;
  final void Function(String) onBuscar;
  final List<Pedido> resultados;
  final void Function(Pedido) onElegirPedido;
  const _BarraSuperior({
    required this.lav,
    required this.porRecibir,
    required this.onBuscar,
    required this.resultados,
    required this.onElegirPedido,
  });

  @override
  ConsumerState<_BarraSuperior> createState() => _BarraSuperiorState();
}

class _BarraSuperiorState extends ConsumerState<_BarraSuperior> {
  late Timer _reloj;
  DateTime _ahora = DateTime.now();
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(
      const Duration(seconds: 20),
      (_) => setState(() => _ahora = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _reloj.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(currentAppUserProvider).valueOrNull;
    final hora =
        '${_ahora.hour.toString().padLeft(2, '0')}:${_ahora.minute.toString().padLeft(2, '0')}';
    final angosto = MediaQuery.sizeOf(context).width < 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Vidrio(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_azul, Color(0xFF5AA0FF)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.local_laundry_service,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.lav.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _tinta,
                    ),
                  ),
                  Text(
                    widget.lav.horarioAtencion.estaVacio
                        ? 'Horario sin definir'
                        : widget.lav.horarioAtencion.formatoLegible,
                    style: const TextStyle(fontSize: 11, color: _gris),
                  ),
                ],
              ),
              const SizedBox(width: 18),
              if (!angosto)
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 18, color: _gris),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            onChanged: widget.onBuscar,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: 'Buscar pedido por código o cliente…',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F9EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22B45A),
                            shape: BoxShape.circle,
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fadeOut(duration: 900.ms),
                    const SizedBox(width: 6),
                    Text(
                      'En vivo $hora',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Avisos(
                lav: widget.lav,
                porRecibir: widget.porRecibir,
                onElegirPedido: widget.onElegirPedido,
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                tooltip: 'Mi cuenta',
                onSelected: (v) {
                  if (v == 'salir')
                    ref.read(authRepositoryProvider).cerrarSesion();
                  if (v == 'editar') context.push('/admin/editar');
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'editar',
                    child: Text('Editar mi lavandería'),
                  ),
                  PopupMenuItem(value: 'salir', child: Text('Cerrar sesión')),
                ],
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: _azul.withValues(alpha: 0.12),
                      backgroundImage: (u?.fotoBase64.isNotEmpty ?? false)
                          ? MemoryImage(base64Decode(u!.fotoBase64))
                          : null,
                      child: (u?.fotoBase64.isNotEmpty ?? false)
                          ? null
                          : Text(
                              (u?.nombre.isNotEmpty ?? false)
                                  ? u!.nombre[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                color: _azul,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    if (!angosto) ...[
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            u?.nombre ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _tinta,
                            ),
                          ),
                          const Text(
                            'Dueño · Administrador',
                            style: TextStyle(fontSize: 11, color: _gris),
                          ),
                        ],
                      ),
                      const Icon(Icons.expand_more, color: _gris),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.resultados.isNotEmpty)
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 440,
              child: _Vidrio(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final p in widget.resultados)
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.receipt_long_outlined,
                          color: _azul,
                        ),
                        title: Text(
                          '#${p.id.substring(0, 5).toUpperCase()} · ${p.clienteNombre}',
                        ),
                        subtitle: Text(
                          '${p.estado.label} · ${p.totalPrendas} prendas',
                        ),
                        onTap: () {
                          _ctrl.clear();
                          widget.onElegirPedido(p);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Kpis extends StatelessWidget {
  final List<Pedido> pedidos;
  final List<Pedido> activos;
  final bool compacto;
  const _Kpis({
    required this.pedidos,
    required this.activos,
    required this.compacto,
  });

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final deHoy = pedidos.where(
      (p) =>
          p.creadoEn != null &&
          p.creadoEn!.year == hoy.year &&
          p.creadoEn!.month == hoy.month &&
          p.creadoEn!.day == hoy.day,
    );
    final ingresosHoy = deHoy.fold<double>(0, (a, p) => a + p.costoTotal);
    final enCola = activos
        .where((p) => p.estado == EstadoPedido.recibido)
        .length;
    final lavando = activos
        .where((p) => p.estado == EstadoPedido.enProceso)
        .length;
    final listos = activos.where((p) => p.estado == EstadoPedido.listo).length;
    final items = [
      (
        Icons.inventory_2_outlined,
        'Pedidos en cola',
        '$enCola',
        '${deHoy.length} hoy',
      ),
      (
        Icons.local_laundry_service_outlined,
        'Lavando ahora',
        '$lavando',
        'en máquinas',
      ),
      (Icons.check_circle_outline, 'Listos', '$listos', 'para entregar'),
      if (!compacto)
        (
          Icons.payments_outlined,
          'Ingresos de hoy',
          'Bs ${ingresosHoy.toStringAsFixed(0)}',
          'pedidos creados hoy',
        ),
    ];
    return Row(
      children: [
        for (final (icono, titulo, valor, pie) in items)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: compacto ? 150 : 172,
              child: _Vidrio(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _azul.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icono, color: _azul, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(fontSize: 11, color: _gris),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            valor,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _tinta,
                            ),
                          ),
                          Text(
                            pie,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _gris,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
          ),
      ],
    );
  }
}

class _Riel extends StatelessWidget {
  final Ciudad3DControl control;
  final void Function(String ruta) onIr;
  final VoidCallback onSoporte;
  final VoidCallback onLavanderia;
  const _Riel({
    required this.control,
    required this.onIr,
    required this.onSoporte,
    required this.onLavanderia,
  });

  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, String t, VoidCallback f) => Tooltip(
      message: t,
      preferBelow: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: f,
        child: SizedBox(
          width: 52,
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(i, color: _tinta, size: 21),
              Text(
                t,
                style: const TextStyle(fontSize: 9, color: _gris),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ],
          ),
        ),
      ),
    );
    return _Vidrio(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        children: [
          b(Icons.storefront_outlined, 'Local', () {
            control.enfocar('lavanderia');
            onLavanderia();
          }),
          b(
            Icons.location_city_outlined,
            'Ciudad',
            () => control.enfocar('ciudad'),
          ),
          const Divider(height: 10, indent: 8, endIndent: 8),
          b(Icons.badge_outlined, 'Equipo', () => onIr('/admin/empleados')),
          b(
            Icons.bar_chart_outlined,
            'Finanzas',
            () => onIr('/admin/finanzas'),
          ),
          b(Icons.edit_outlined, 'Editar', () => onIr('/admin/editar')),
          b(Icons.support_agent_outlined, 'Soporte', onSoporte),
          const Divider(height: 10, indent: 8, endIndent: 8),
          b(Icons.add, 'Acercar', () => control.zoom(1)),
          b(Icons.remove, 'Alejar', () => control.zoom(-1)),
          b(Icons.rotate_90_degrees_ccw_outlined, 'Girar', control.rotar),
        ],
      ),
    );
  }
}

class _Inspector extends ConsumerWidget {
  final Seleccion3D sel;
  final Lavanderia lav;
  final List<AppUser> equipo;
  final List<Pedido> pedidos;
  final List<IntencionPedido> intenciones;
  final VoidCallback onCerrar;
  final void Function(Seleccion3D) onVer;
  const _Inspector({
    required this.sel,
    required this.lav,
    required this.equipo,
    required this.pedidos,
    required this.intenciones,
    required this.onCerrar,
    required this.onVer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget cuerpo;
    switch (sel.tipo) {
      case 'empleado':
        final e = equipo.where((x) => x.uid == sel.id).firstOrNull;
        cuerpo = e == null
            ? const Text('Empleado no encontrado')
            : _InfoEmpleado(e: e, pedidos: pedidos);
      case 'pedido':
        final p = pedidos.where((x) => x.id == sel.id).firstOrNull;
        cuerpo = p == null
            ? const Text('El pedido ya no está activo')
            : _InfoPedido(p: p);
      case 'intencion':
        final i = intenciones.where((x) => x.clienteUid == sel.id).firstOrNull;
        cuerpo = _InfoIntencion(i: i);
      default:
        cuerpo = _InfoLavanderia(
          lav: lav,
          equipo: equipo,
          pedidos: pedidos,
          onVer: onVer,
        );
    }
    return _Vidrio(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - 420,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      switch (sel.tipo) {
                        'empleado' => 'EMPLEADO',
                        'pedido' => 'PEDIDO',
                        'intencion' => 'PEDIDO EN CONSTRUCCIÓN',
                        _ => 'MI LAVANDERÍA',
                      },
                      style: const TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: _azul,
                      ),
                    ),
                  ),
                  if (sel.tipo != 'lavanderia')
                    InkWell(
                      onTap: onCerrar,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 18, color: _gris),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(key: ValueKey(sel), child: cuerpo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _fila(String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 118,
        child: Text(k, style: const TextStyle(fontSize: 12.5, color: _gris)),
      ),
      Expanded(
        child: Text(
          v,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _tinta,
          ),
        ),
      ),
    ],
  ),
);

Widget _chip(String t, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: c.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    t,
    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c),
  ),
);

class _InfoLavanderia extends ConsumerWidget {
  final Lavanderia lav;
  final List<AppUser> equipo;
  final List<Pedido> pedidos;
  final void Function(Seleccion3D) onVer;
  const _InfoLavanderia({
    required this.lav,
    required this.equipo,
    required this.pedidos,
    required this.onVer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promedio = ref
        .watch(calificacionPromedioProvider(lav.id))
        .valueOrNull;
    final entregados = pedidos
        .where((p) => p.estado == EstadoPedido.entregado)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lav.nombre,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _tinta,
          ),
        ),
        Text(
          lav.direccion,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: _gris),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _chip(
              lav.activo ? 'Operando' : 'Desactivada',
              lav.activo ? const Color(0xFF15803D) : Colors.red,
            ),
            if (promedio != null)
              _chip(
                '★ ${promedio.toStringAsFixed(1)}',
                const Color(0xFFB7791F),
              ),
            if (lav.entregaDomicilio) _chip('Recojo a domicilio', _azul),
          ],
        ),
        const SizedBox(height: 10),
        _fila(
          'Horario',
          lav.horarioAtencion.estaVacio
              ? 'Sin definir (Editar)'
              : lav.horarioAtencion.formatoLegible,
        ),
        _fila('Pedidos entregados', '$entregados'),
        _fila('Envío base', 'Bs ${lav.costoEnvio.toStringAsFixed(0)}'),
        const Divider(height: 22),
        Text(
          'Equipo (${equipo.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, color: _tinta),
        ),
        const SizedBox(height: 6),
        if (equipo.isEmpty)
          const Text(
            'Aún no tienes empleados. Contrata desde "Equipo".',
            style: TextStyle(fontSize: 12, color: _gris),
          ),
        for (final e in equipo)
          InkWell(
            onTap: () => onVer(Seleccion3D('empleado', e.uid)),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    actividades[actividadDe(e)]?.$1 ?? Icons.person,
                    size: 18,
                    color: _azul,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.nombre,
                      style: const TextStyle(fontSize: 13, color: _tinta),
                    ),
                  ),
                  Text(
                    actividades[actividadDe(e)]?.$2 ?? actividadDe(e),
                    style: const TextStyle(fontSize: 11.5, color: _gris),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in lav.servicios.take(8))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s,
                  style: const TextStyle(fontSize: 11, color: _tinta),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoEmpleado extends StatelessWidget {
  final AppUser e;
  final List<Pedido> pedidos;
  const _InfoEmpleado({required this.e, required this.pedidos});

  @override
  Widget build(BuildContext context) {
    final (icono, texto) =
        actividades[actividadDe(e)] ?? (Icons.person, actividadDe(e));
    final desde = (e.actividadEn == null || actividadDe(e) != e.actividad)
        ? null
        : DateTime.now().difference(e.actividadEn!).inMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _azul.withValues(alpha: 0.12),
              backgroundImage: e.fotoBase64.isNotEmpty
                  ? MemoryImage(base64Decode(e.fotoBase64))
                  : null,
              child: e.fotoBase64.isEmpty
                  ? Text(
                      e.nombre.isEmpty ? '?' : e.nombre[0],
                      style: const TextStyle(
                        color: _azul,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _tinta,
                    ),
                  ),
                  Text(
                    e.telefono.isEmpty ? e.email : e.telefono,
                    style: const TextStyle(fontSize: 12, color: _gris),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _azul.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icono, color: _azul),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _tinta,
                  ),
                ),
              ),
              if (desde != null)
                Text(
                  desde < 1 ? 'recién' : 'hace $desde min',
                  style: const TextStyle(fontSize: 11.5, color: _gris),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _fila(
          'Salario mensual',
          e.salarioEmpleado == null
              ? 'Sin definir'
              : 'Bs ${e.salarioEmpleado!.toStringAsFixed(0)}',
        ),
        if (e.edad != null) _fila('Edad', '${e.edad} años'),
        _fila(
          'Pedidos en curso del local',
          '${pedidos.where((p) => p.estado == EstadoPedido.enProceso).length}',
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => verPerfilEmpleado(context, e),
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('Ver perfil completo'),
          ),
        ),
      ],
    );
  }
}

class _InfoPedido extends ConsumerWidget {
  final Pedido p;
  const _InfoPedido({required this.p});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EstadoPedido? siguiente = switch (p.estado) {
      EstadoPedido.recibido => EstadoPedido.enProceso,
      EstadoPedido.enProceso => EstadoPedido.listo,
      EstadoPedido.listo =>
        p.necesitaRepartidor ? null : EstadoPedido.entregado,
      EstadoPedido.entregado => null,
    };
    if (p.estado == EstadoPedido.recibido && !p.ropaRecibida) siguiente = null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '#${p.id.substring(0, 5).toUpperCase()}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _tinta,
              ),
            ),
            const SizedBox(width: 8),
            _chip(p.estado.label, _azul),
          ],
        ),
        Text(
          p.clienteNombre.isEmpty ? 'Cliente' : p.clienteNombre,
          style: const TextStyle(fontSize: 13, color: _gris),
        ),
        const SizedBox(height: 10),
        _fila('Entrega', p.tipoEntrega.label),
        if (p.necesitaRepartidor)
          _fila(
            'Repartidor',
            p.repartidorUid == null
                ? 'Buscando…'
                : '${p.repartidorNombre} · ${p.etapaReparto.label}',
          ),
        if (p.direccionRecojo.isNotEmpty) _fila('Dirección', p.direccionRecojo),
        _fila('Ropa en el local', p.ropaRecibida ? 'Sí' : 'Todavía no'),
        _fila('Total', 'Bs ${p.costoTotal.toStringAsFixed(0)}'),
        const Divider(height: 20),
        for (final e in p.prendas.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.checkroom_outlined, size: 16, color: _azul),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(e.key, style: const TextStyle(fontSize: 12.5)),
                ),
                Text(
                  '×${e.value}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        if (p.notas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '“${p.notas}”',
              style: const TextStyle(fontSize: 12, color: _gris),
            ),
          ),
        const SizedBox(height: 12),
        if (puedeRegistrarPrendas(p))
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => abrirRegistrarPrendas(context, pedido: p),
              icon: const Icon(Icons.document_scanner_outlined),
              label: Text(
                esperaRopaDelCliente(p)
                    ? 'Recibir y registrar prendas (IA)'
                    : 'Registrar prendas (IA)',
              ),
            ),
          ),
        if (esperaRopaDelCliente(p))
          TextButton(
            onPressed: () => recibirRopa(ref, p),
            child: const Text('Solo marcar como recibida'),
          ),
        if (siguiente != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => avanzarPedido(ref, p, siguiente!),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text('Marcar "${siguiente.label}"'),
            ),
          ),
      ],
    );
  }
}

class _InfoIntencion extends StatelessWidget {
  final IntencionPedido? i;
  const _InfoIntencion({required this.i});

  @override
  Widget build(BuildContext context) {
    if (i == null) return const Text('El cliente ya terminó.');
    final min = i!.actualizadoEn == null
        ? null
        : DateTime.now().difference(i!.actualizadoEn!).inMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          i!.clienteNombre,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _tinta,
          ),
        ),
        const SizedBox(height: 6),
        Text(switch (i!.estado) {
          EstadoIntencion.armando => 'Está eligiendo prendas en tu lavandería ahora mismo. Si confirma, la casa se termina de construir; si sale, la obra se cancela.',
          EstadoIntencion.confirmada => 'Confirmó su pedido.',
          EstadoIntencion.cancelada => 'Salió sin confirmar.',
        }, style: const TextStyle(fontSize: 12.5, color: _gris)),
        if (min != null)
          _fila('Empezó', min < 1 ? 'hace instantes' : 'hace $min min'),
      ],
    );
  }
}

class _Seguimiento extends StatelessWidget {
  final Pedido? pedido;
  final void Function(Pedido) onTap;
  const _Seguimiento({required this.pedido, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final pasos = p == null
        ? const <(String, IconData)>[]
        : p.necesitaRepartidor
        ? const [
            ('Confirmado', Icons.receipt_long_outlined),
            ('Recogido', Icons.two_wheeler_outlined),
            ('En el local', Icons.storefront_outlined),
            ('Lavando', Icons.local_laundry_service_outlined),
            ('Listo', Icons.check_circle_outline),
            ('Entregado', Icons.home_outlined),
          ]
        : const [
            ('Confirmado', Icons.receipt_long_outlined),
            ('Ropa recibida', Icons.move_to_inbox_outlined),
            ('Lavando', Icons.local_laundry_service_outlined),
            ('Listo', Icons.check_circle_outline),
            ('Entregado', Icons.done_all),
          ];
    int actual = 0;
    if (p != null) {
      if (p.necesitaRepartidor) {
        actual = switch (p.estado) {
          EstadoPedido.enProceso => 3,
          EstadoPedido.listo =>
            p.etapaReparto == EtapaReparto.devolviendo ? 4 : 4,
          EstadoPedido.entregado => 5,
          EstadoPedido.recibido =>
            p.ropaRecibida
                ? 2
                : (p.etapaReparto == EtapaReparto.recogido ? 1 : 0),
        };
      } else {
        actual = switch (p.estado) {
          EstadoPedido.recibido => p.ropaRecibida ? 1 : 0,
          EstadoPedido.enProceso => 2,
          EstadoPedido.listo => 3,
          EstadoPedido.entregado => 4,
        };
      }
    }
    return _Vidrio(
      child: p == null
          ? const Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: _azul),
                SizedBox(width: 10),
                Text(
                  'Seguimiento de pedidos · no hay pedidos activos',
                  style: TextStyle(color: _gris),
                ),
              ],
            )
          : InkWell(
              onTap: () => onTap(p),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        color: _azul,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Seguimiento del pedido',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _tinta,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '#${p.id.substring(0, 5).toUpperCase()} · ${p.clienteNombre.isEmpty ? 'Cliente' : p.clienteNombre.split(' ').first}',
                        style: const TextStyle(fontSize: 12, color: _gris),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < pasos.length; i++) ...[
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: i == actual ? 34 : 28,
                              height: i == actual ? 34 : 28,
                              decoration: BoxDecoration(
                                color: i <= actual
                                    ? _azul
                                    : const Color(0xFFE6EAF5),
                                shape: BoxShape.circle,
                                boxShadow: i == actual
                                    ? [
                                        BoxShadow(
                                          color: _azul.withValues(alpha: 0.35),
                                          blurRadius: 12,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                pasos[i].$2,
                                size: 16,
                                color: i <= actual ? Colors.white : _gris,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pasos[i].$1,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: i == actual
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: i <= actual ? _tinta : _gris,
                              ),
                            ),
                          ],
                        ),
                        if (i < pasos.length - 1)
                          Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: i < actual
                                    ? _azul
                                    : const Color(0xFFE6EAF5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _ListaPestanas extends StatelessWidget {
  final int pestana;
  final void Function(int) onPestana;
  final List<Pedido> activos;
  final List<AppUser> equipo;
  final List<IntencionPedido> intenciones;
  final void Function(Seleccion3D) onElegir;
  const _ListaPestanas({
    required this.pestana,
    required this.onPestana,
    required this.activos,
    required this.equipo,
    required this.intenciones,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      'Pedidos ${activos.length}',
      'Equipo ${equipo.length}',
      'En obra ${intenciones.length}',
    ];
    Widget fila({
      required IconData icono,
      required String titulo,
      required String sub,
      required String etiqueta,
      required Color color,
      required VoidCallback onTap,
    }) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icono, size: 18, color: _azul),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _tinta,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 11, color: _gris),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _chip(etiqueta, color),
            const Icon(Icons.chevron_right, size: 18, color: _gris),
          ],
        ),
      ),
    );
    final List<Widget> filas = switch (pestana) {
      0 => [
        for (final p in activos.take(30))
          fila(
            icono: p.necesitaRepartidor
                ? Icons.two_wheeler_outlined
                : Icons.directions_walk,
            titulo:
                '#${p.id.substring(0, 5).toUpperCase()} · ${p.clienteNombre.isEmpty ? 'Cliente' : p.clienteNombre}',
            sub:
                '${p.totalPrendas} prendas · ${p.necesitaRepartidor ? p.etapaReparto.label : 'lo trae el cliente'}',
            etiqueta: p.estado.label,
            color: switch (p.estado) {
              EstadoPedido.recibido => const Color(0xFFB7791F),
              EstadoPedido.enProceso => _azul,
              EstadoPedido.listo => const Color(0xFF15803D),
              EstadoPedido.entregado => _gris,
            },
            onTap: () => onElegir(Seleccion3D('pedido', p.id)),
          ),
      ],
      1 => [
        for (final e in equipo)
          fila(
            icono: actividades[actividadDe(e)]?.$1 ?? Icons.person,
            titulo: e.nombre,
            sub: e.telefono.isEmpty ? e.email : e.telefono,
            etiqueta: actividades[actividadDe(e)]?.$2 ?? actividadDe(e),
            color: actividadDe(e) == 'descanso' ? _gris : _azul,
            onTap: () => onElegir(Seleccion3D('empleado', e.uid)),
          ),
      ],
      _ => [
        for (final i in intenciones)
          fila(
            icono: Icons.construction_outlined,
            titulo: i.clienteNombre,
            sub: 'Armando un pedido ahora',
            etiqueta: 'En obra',
            color: const Color(0xFFB7791F),
            onTap: () => onElegir(Seleccion3D('intencion', i.clienteUid)),
          ),
      ],
    };
    return _Vidrio(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    label: Text(tabs[i], style: const TextStyle(fontSize: 12)),
                    selected: pestana == i,
                    onSelected: (_) => onPestana(i),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 210),
            child: filas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Nada por aquí todavía',
                      style: TextStyle(color: _gris, fontSize: 12.5),
                    ),
                  )
                : ListView(shrinkWrap: true, children: filas),
          ),
        ],
      ),
    );
  }
}

/// Selector de actividad del empleado (también lo usa su propio panel).
class SelectorActividad extends ConsumerWidget {
  const SelectorActividad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(currentAppUserProvider).valueOrNull;
    if (u == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in actividades.entries)
          ChoiceChip(
            avatar: Icon(
              e.value.$1,
              size: 18,
              color: u.actividad == e.key ? Colors.white : AppTheme.primary,
            ),
            label: Text(e.value.$2),
            selected: u.actividad == e.key,
            selectedColor: AppTheme.primary,
            labelStyle: TextStyle(
              color: u.actividad == e.key ? Colors.white : null,
              fontWeight: FontWeight.w600,
            ),
            showCheckmark: false,
            onSelected: (_) =>
                ref.read(authRepositoryProvider).cambiarActividad(u.uid, e.key),
          ),
      ],
    );
  }
}

/// Campana del panel: lo que espera al admin (ropa por recibir y gente que
/// pidió trabajar). Cada aviso lleva directo a donde se resuelve.
class _Avisos extends ConsumerWidget {
  final Lavanderia lav;
  final List<Pedido> porRecibir;
  final void Function(Pedido) onElegirPedido;
  const _Avisos({
    required this.lav,
    required this.porRecibir,
    required this.onElegirPedido,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudes =
        ref.watch(solicitudesEmpleadoPendientesProvider(lav.id)).valueOrNull ??
        const [];
    final total = porRecibir.length + solicitudes.length;
    return PopupMenuButton<Object>(
      tooltip: 'Avisos',
      onSelected: (v) {
        if (v is Pedido) onElegirPedido(v);
        if (v == 'empleados') context.push('/admin/empleados');
      },
      itemBuilder: (_) => [
        if (total == 0)
          const PopupMenuItem(
            enabled: false,
            child: Text('No tienes avisos nuevos.'),
          ),
        for (final p in porRecibir.take(8))
          PopupMenuItem(
            value: p,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_laundry_service_outlined),
              title: Text('Ropa por recibir · ${p.clienteNombre}'),
              subtitle: Text(
                p.tipoEntrega == TipoEntrega.recojoDomicilio
                    ? 'Recojo a domicilio'
                    : 'La trae el cliente',
              ),
            ),
          ),
        if (solicitudes.isNotEmpty)
          PopupMenuItem(
            value: 'empleados',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: Text(
                solicitudes.length == 1
                    ? '1 persona quiere trabajar contigo'
                    : '${solicitudes.length} personas quieren trabajar contigo',
              ),
              subtitle: const Text('Revisar en Empleados'),
            ),
          ),
      ],
      child: Badge(
        isLabelVisible: total > 0,
        label: Text('$total'),
        child: const Icon(Icons.notifications_none_rounded, color: _tinta),
      ),
    );
  }
}
