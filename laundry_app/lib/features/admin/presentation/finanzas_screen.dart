import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../client/data/lavanderia_repository.dart';
import '../../client/data/pedido_repository.dart';
import '../../shared/models/app_user.dart';
import '../../shared/models/lavanderia.dart';
import '../../shared/models/pedido.dart';
import '../data/admin_empleados_repository.dart';
import '../data/finanzas_repository.dart';
import 'finanzas_widgets.dart';

/// Categorías típicas de una lavandería, para que registrar un gasto sea
/// casi un solo toque en vez de escribir la descripción cada vez.
const _categoriasGasto = [
  ('Electricidad', Icons.bolt_outlined),
  ('Agua', Icons.water_drop_outlined),
  ('Detergente / jabón', Icons.soap_outlined),
  ('Suavizante / Ace', Icons.local_laundry_service_outlined),
  ('Mantenimiento de lavadora', Icons.build_outlined),
  ('Otro', Icons.receipt_long_outlined),
];

enum _Rango { semana, mes, ano, dia }

String _fmtFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class FinanzasScreen extends ConsumerStatefulWidget {
  const FinanzasScreen({super.key});

  @override
  ConsumerState<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends ConsumerState<FinanzasScreen> {
  _Rango _rango = _Rango.mes;
  DateTime _diaEspecifico = DateTime.now();
  bool _generandoInforme = false;

  DateTimeRange get _rangoFechas {
    final ahora = DateTime.now();
    final hoyFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
    switch (_rango) {
      case _Rango.semana:
        return DateTimeRange(
          start: ahora.subtract(const Duration(days: 7)),
          end: hoyFin,
        );
      case _Rango.mes:
        return DateTimeRange(
          start: DateTime(ahora.year, ahora.month, 1),
          end: hoyFin,
        );
      case _Rango.ano:
        return DateTimeRange(start: DateTime(ahora.year, 1, 1), end: hoyFin);
      case _Rango.dia:
        final d = _diaEspecifico;
        return DateTimeRange(
          start: DateTime(d.year, d.month, d.day),
          end: DateTime(d.year, d.month, d.day, 23, 59, 59),
        );
    }
  }

  String get _rangoEtiqueta {
    final r = _rangoFechas;
    switch (_rango) {
      case _Rango.semana:
        return 'Última semana (${_fmtFecha(r.start)} - ${_fmtFecha(r.end)})';
      case _Rango.mes:
        return 'Este mes (${_fmtFecha(r.start)} - ${_fmtFecha(r.end)})';
      case _Rango.ano:
        return 'Este año (${_fmtFecha(r.start)} - ${_fmtFecha(r.end)})';
      case _Rango.dia:
        return _fmtFecha(_diaEspecifico);
    }
  }

  bool _enRango(DateTime? fecha, DateTimeRange rango) =>
      fecha != null &&
      !fecha.isBefore(rango.start) &&
      !fecha.isAfter(rango.end);

  Future<void> _elegirDia(BuildContext context) async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: _diaEspecifico,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (elegido != null) setState(() => _diaEspecifico = elegido);
  }

  Future<void> _agregarEgreso(
    BuildContext context,
    WidgetRef ref,
    String lavanderiaId, [
    String categoriaInicial = '',
  ]) async {
    final descripcionCtrl = TextEditingController(text: categoriaInicial);
    final montoCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar gasto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descripcionCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: categoriaInicial.isNotEmpty,
              decoration: const InputDecoration(labelText: 'Monto (Bs)'),
            ),
          ],
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
    final monto = double.tryParse(montoCtrl.text.trim()) ?? 0;
    if (descripcionCtrl.text.trim().isEmpty || monto <= 0) return;
    await ref
        .read(finanzasRepositoryProvider)
        .agregarEgreso(lavanderiaId, descripcionCtrl.text.trim(), monto);
  }

  Future<void> _generarInforme({
    required Lavanderia lavanderia,
    required double ingresos,
    required List<Egreso> egresosDelRango,
    required double totalPlanillaPeriodo,
    required List<AppUser> equipo,
    required int diasEnRango,
  }) async {
    setState(() => _generandoInforme = true);
    try {
      final doc = pw.Document();
      final totalEgresosManual = egresosDelRango.fold(
        0.0,
        (a, e) => a + e.monto,
      );
      final totalEgresos = totalEgresosManual + totalPlanillaPeriodo;
      final balance = ingresos - totalEgresos;
      final ahora = DateTime.now();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              lavanderia.nombre,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              lavanderia.direccion,
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Informe financiero',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Periodo: $_rangoEtiqueta',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.Text(
              'Generado: ${_fmtFecha(ahora)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
              },
              children: [
                _filaResumen(
                  'Ingresos',
                  ingresos,
                  PdfColors.green800,
                  negrita: true,
                ),
                _filaResumen(
                  'Egresos totales',
                  totalEgresos,
                  PdfColors.red800,
                  negrita: true,
                ),
                _filaResumen(
                  'Balance',
                  balance,
                  PdfColors.teal800,
                  negrita: true,
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Resumen de gastos por categoría',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            if (egresosDelRango.isEmpty)
              pw.Text(
                'Sin gastos manuales en este periodo.',
                style: const pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 10,
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                },
                children: [
                  _filaTabla(['Categoría', 'Total (Bs)'], esEncabezado: true),
                  for (final entry in _agruparPorCategoria(
                    egresosDelRango,
                  ).entries)
                    _filaTabla([entry.key, entry.value.toStringAsFixed(0)]),
                ],
              ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Detalle de gastos (día por día)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            if (egresosDelRango.isEmpty)
              pw.SizedBox()
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(3),
                  2: pw.FlexColumnWidth(2),
                },
                children: [
                  _filaTabla([
                    'Fecha',
                    'Descripción',
                    'Monto (Bs)',
                  ], esEncabezado: true),
                  for (final e in egresosDelRango)
                    _filaTabla([
                      e.fecha == null ? '-' : _fmtFecha(e.fecha!),
                      e.descripcion,
                      e.monto.toStringAsFixed(0),
                    ]),
                ],
              ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Planilla (prorrateada a $diasEnRango día(s) del periodo)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            if (equipo.isEmpty)
              pw.Text(
                'Sin empleados registrados.',
                style: const pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 10,
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                },
                children: [
                  _filaTabla([
                    'Empleado',
                    'Salario mensual (Bs)',
                    'Prorrateado (Bs)',
                  ], esEncabezado: true),
                  for (final e in equipo)
                    _filaTabla([
                      e.nombre,
                      (e.salarioEmpleado ?? 0).toStringAsFixed(0),
                      ((e.salarioEmpleado ?? 0) * diasEnRango / 30)
                          .toStringAsFixed(0),
                    ]),
                ],
              ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    } finally {
      if (mounted) setState(() => _generandoInforme = false);
    }
  }

  pw.TableRow _filaResumen(
    String etiqueta,
    double valor,
    PdfColor color, {
    bool negrita = false,
  }) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            etiqueta,
            style: pw.TextStyle(
              fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            'Bs ${valor.toStringAsFixed(0)}',
            style: pw.TextStyle(color: color, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// Suma los gastos con la misma descripción (ej. varios "Electricidad"
  /// en distintos días) en una sola línea de totales por categoría.
  Map<String, double> _agruparPorCategoria(List<Egreso> egresos) {
    final porCategoria = <String, double>{};
    for (final e in egresos) {
      porCategoria[e.descripcion] =
          (porCategoria[e.descripcion] ?? 0) + e.monto;
    }
    final entradas = porCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entradas);
  }

  pw.TableRow _filaTabla(List<String> celdas, {bool esEncabezado = false}) {
    return pw.TableRow(
      decoration: esEncabezado
          ? const pw.BoxDecoration(color: PdfColors.grey200)
          : null,
      children: [
        for (final c in celdas)
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              c,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: esEncabezado
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  List<PuntoSerie> _serie(
    List<Pedido> entregados,
    List<Egreso> gastos,
    DateTimeRange r,
    double planillaMensual,
  ) {
    const meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    if (_rango == _Rango.ano) {
      return [
        for (var m = 1; m <= r.end.month; m++)
          PuntoSerie(
            meses[m - 1],
            entregados
                .where((p) => p.creadoEn!.month == m)
                .fold(0.0, (a, p) => a + p.costoTotal),
            gastos
                    .where((e) => e.fecha!.month == m)
                    .fold(0.0, (a, e) => a + e.monto) +
                planillaMensual,
          ),
      ];
    }
    if (_rango == _Rango.dia) {
      return [
        for (var h = 6; h <= 22; h += 2)
          PuntoSerie(
            '${h}h',
            entregados
                .where((p) => p.creadoEn!.hour >= h && p.creadoEn!.hour < h + 2)
                .fold(0.0, (a, p) => a + p.costoTotal),
            gastos
                .where((e) => e.fecha!.hour >= h && e.fecha!.hour < h + 2)
                .fold(0.0, (a, e) => a + e.monto),
          ),
      ];
    }
    final dias = r.end.difference(r.start).inDays + 1;
    return [
      for (var i = 0; i < dias; i++)
        () {
          final d = DateTime(r.start.year, r.start.month, r.start.day + i);
          bool mismo(DateTime? x) =>
              x != null &&
              x.year == d.year &&
              x.month == d.month &&
              x.day == d.day;
          return PuntoSerie(
            _rango == _Rango.semana ? '${d.day}/${d.month}' : '${d.day}',
            entregados
                .where((p) => mismo(p.creadoEn))
                .fold(0.0, (a, p) => a + p.costoTotal),
            gastos
                    .where((e) => mismo(e.fecha))
                    .fold(0.0, (a, e) => a + e.monto) +
                planillaMensual / 30,
          );
        }(),
    ];
  }

  List<(String, double, IconData)> _desglose(
    List<Egreso> gastos,
    double planilla,
  ) {
    final acum = <String, double>{};
    final iconos = {for (final (n, i) in _categoriasGasto) n: i};
    for (final e in gastos) {
      final cat = _categoriasGasto
          .map((c) => c.$1)
          .firstWhere(
            (n) => e.descripcion.toLowerCase().startsWith(n.toLowerCase()),
            orElse: () => 'Otro',
          );
      acum[cat] = (acum[cat] ?? 0) + e.monto;
    }
    if (planilla > 0) acum['Planilla'] = planilla;
    final filas = [
      for (final en in acum.entries)
        (
          en.key,
          en.value,
          en.key == 'Planilla'
              ? Icons.groups_outlined
              : (iconos[en.key] ?? Icons.receipt_long_outlined),
        ),
    ]..sort((x, y) => y.$2.compareTo(x.$2));
    return filas;
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final lavanderiaId = appUser?.lavanderiaId;

    return Scaffold(
      appBar: AppBar(title: const Text('Finanzas')),
      body: lavanderiaId == null
          ? const Center(child: Text('No tienes una lavandería asignada.'))
          : Consumer(
              builder: (context, ref, _) {
                final lavanderiaAsync = ref.watch(
                  lavanderiaPorIdProvider(lavanderiaId),
                );
                final pedidosAsync = ref.watch(
                  pedidosLavanderiaProvider(lavanderiaId),
                );
                final egresosAsync = ref.watch(egresosProvider(lavanderiaId));
                final equipoAsync = ref.watch(
                  equipoActualProvider(lavanderiaId),
                );

                if (!lavanderiaAsync.hasValue ||
                    !pedidosAsync.hasValue ||
                    !egresosAsync.hasValue ||
                    !equipoAsync.hasValue) {
                  final error =
                      lavanderiaAsync.error ??
                      pedidosAsync.error ??
                      egresosAsync.error ??
                      equipoAsync.error;
                  if (error != null)
                    return Center(child: Text('Error: $error'));
                  return const Center(child: CircularProgressIndicator());
                }

                final lavanderia = lavanderiaAsync.value;
                final pedidos = pedidosAsync.value!;
                final egresos = egresosAsync.value!;
                final equipo = equipoAsync.value!;
                if (lavanderia == null) {
                  return const Center(
                    child: Text('No se encontró tu lavandería.'),
                  );
                }

                final rango = _rangoFechas;
                final diasEnRango =
                    rango.end.difference(rango.start).inDays + 1;

                final entregados = pedidos
                    .where(
                      (p) =>
                          p.estado == EstadoPedido.entregado &&
                          _enRango(p.creadoEn, rango),
                    )
                    .toList();
                final ingresos = entregados.fold(
                  0.0,
                  (acc, p) => acc + p.costoTotal,
                );
                final porCobrar = pedidos
                    .where(
                      (p) =>
                          p.estado != EstadoPedido.entregado &&
                          _enRango(p.creadoEn, rango),
                    )
                    .fold(0.0, (acc, p) => acc + p.costoTotal);

                final egresosDelRango = egresos
                    .where((e) => _enRango(e.fecha, rango))
                    .toList();
                final totalGastosManual = egresosDelRango.fold(
                  0.0,
                  (acc, e) => acc + e.monto,
                );
                final totalPlanillaMensual = equipo.fold(
                  0.0,
                  (acc, e) => acc + (e.salarioEmpleado ?? 0),
                );
                final totalPlanillaPeriodo =
                    totalPlanillaMensual * diasEnRango / 30;
                final totalEgresos = totalGastosManual + totalPlanillaPeriodo;
                final balance = ingresos - totalEgresos;

                // Periodo anterior de la misma duración, para la variación.
                final duracion = rango.end.difference(rango.start);
                final previo = DateTimeRange(
                  start: rango.start.subtract(
                    duracion + const Duration(seconds: 1),
                  ),
                  end: rango.start.subtract(const Duration(seconds: 1)),
                );
                final ingPrevio = pedidos
                    .where(
                      (p) =>
                          p.estado == EstadoPedido.entregado &&
                          _enRango(p.creadoEn, previo),
                    )
                    .fold(0.0, (acc, p) => acc + p.costoTotal);
                final egrPrevio =
                    egresos
                        .where((e) => _enRango(e.fecha, previo))
                        .fold(0.0, (acc, e) => acc + e.monto) +
                    totalPlanillaMensual *
                        (previo.end.difference(previo.start).inDays + 1) /
                        30;
                final balPrevio = ingPrevio - egrPrevio;
                final variacion = balPrevio.abs() < 1
                    ? null
                    : (balance - balPrevio) / balPrevio.abs() * 100;

                // — indicadores de salud del negocio —
                final cobertura = totalEgresos > 0
                    ? ingresos / totalEgresos * 100
                    : (ingresos > 0 ? 100.0 : 0.0);
                final pesoPlanilla = ingresos > 0
                    ? totalPlanillaPeriodo / ingresos * 100
                    : null;
                final porCliente = <String, int>{};
                for (final p in entregados) {
                  porCliente[p.clienteId] = (porCliente[p.clienteId] ?? 0) + 1;
                }
                final recurrentes = porCliente.isEmpty
                    ? null
                    : porCliente.values.where((n) => n > 1).length /
                          porCliente.length *
                          100;
                final ahora = DateTime.now();
                final diasMes = DateTime(ahora.year, ahora.month + 1, 0).day;
                final proyeccion = _rango == _Rango.mes && ahora.day > 2
                    ? ingresos / ahora.day * diasMes
                    : null;
                final prendasTop = <String, double>{};
                for (final p in entregados) {
                  p.prendas.forEach(
                    (k, v) => prendasTop[k] = (prendasTop[k] ?? 0) + v,
                  );
                }
                final prendasFilas =
                    (prendasTop.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .take(6)
                        .map((e) => (e.key, e.value, Icons.checkroom_outlined))
                        .toList();
                final salud = <IndicadorSalud>[
                  IndicadorSalud(
                    'Cobertura de egresos',
                    '${cobertura.toStringAsFixed(0)}%',
                    cobertura >= 100
                        ? 'Tus ingresos ya cubren todo lo que gastas.'
                        : 'Te falta Bs ${(totalEgresos - ingresos).toStringAsFixed(0)} para el punto de equilibrio.',
                    Icons.balance_outlined,
                    cobertura >= 100 ? colIngreso : Colors.orange,
                  ),
                  IndicadorSalud(
                    'Planilla / ingresos',
                    pesoPlanilla == null
                        ? '—'
                        : '${pesoPlanilla.toStringAsFixed(0)}%',
                    pesoPlanilla == null
                        ? 'Aún sin ingresos.'
                        : (pesoPlanilla <= 35
                              ? 'Sueldos en rango sano (hasta ~35%).'
                              : 'Los sueldos pesan mucho en tus ingresos.'),
                    Icons.groups_outlined,
                    pesoPlanilla == null || pesoPlanilla <= 35
                        ? AppTheme.primary
                        : colEgreso,
                  ),
                  IndicadorSalud(
                    'Clientes recurrentes',
                    recurrentes == null
                        ? '—'
                        : '${recurrentes.toStringAsFixed(0)}%',
                    recurrentes == null
                        ? 'Sin pedidos cobrados.'
                        : 'Clientes que volvieron a pedir en el periodo.',
                    Icons.repeat_rounded,
                    const Color(0xFF8B5CF6),
                  ),
                  IndicadorSalud(
                    'Proyección del mes',
                    proyeccion == null ? '—' : bs(proyeccion),
                    proyeccion == null
                        ? 'Disponible en la vista "Mes" desde el día 3.'
                        : 'Si sigues a este ritmo, así cerrarás el mes.',
                    Icons.trending_up_rounded,
                    AppTheme.secondary,
                  ),
                ];

                final serie = _serie(
                  entregados,
                  egresosDelRango,
                  rango,
                  totalPlanillaMensual,
                );
                final desglose = _desglose(
                  egresosDelRango,
                  totalPlanillaPeriodo,
                );
                final movimientos =
                    <Movimiento>[
                      for (final p in entregados)
                        Movimiento(
                          'Pedido · ${p.totalPrendas} prendas',
                          p.tipoEntrega == TipoEntrega.recojoDomicilio
                              ? 'Con delivery'
                              : 'En local',
                          p.costoTotal,
                          p.creadoEn,
                        ),
                      for (final e in egresosDelRango)
                        Movimiento(e.descripcion, 'Gasto', -e.monto, e.fecha),
                    ]..sort(
                      (x, y) => (y.fecha ?? DateTime(2000)).compareTo(
                        x.fecha ?? DateTime(2000),
                      ),
                    );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    SegmentedButton<_Rango>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: _Rango.semana,
                          label: Text('7 días'),
                        ),
                        ButtonSegment(value: _Rango.mes, label: Text('Mes')),
                        ButtonSegment(value: _Rango.ano, label: Text('Año')),
                        ButtonSegment(
                          value: _Rango.dia,
                          label: Icon(Icons.calendar_today, size: 16),
                        ),
                      ],
                      selected: {_rango},
                      onSelectionChanged: (v) async {
                        setState(() => _rango = v.first);
                        if (v.first == _Rango.dia) await _elegirDia(context);
                      },
                    ),
                    const SizedBox(height: 14),
                    TarjetaBalance(
                      balance: balance,
                      ingresos: ingresos,
                      egresos: totalEgresos,
                      variacion: variacion,
                      periodo: _rangoEtiqueta.contains('(')
                          ? _rangoEtiqueta
                                .substring(0, _rangoEtiqueta.indexOf('('))
                                .trim()
                          : _rangoEtiqueta,
                    ),
                    const SizedBox(height: 12),
                    FilaIndicadores(
                      items: [
                        (
                          'Pedidos cobrados',
                          '${entregados.length}',
                          Icons.receipt_long_outlined,
                        ),
                        (
                          'Ticket promedio',
                          entregados.isEmpty
                              ? '—'
                              : bs(ingresos / entregados.length),
                          Icons.shopping_bag_outlined,
                        ),
                        (
                          'Por cobrar',
                          bs(porCobrar),
                          Icons.hourglass_bottom_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    BloqueFinanzas(
                      titulo: 'Ingresos vs. egresos',
                      subtitulo: 'Toca una barra para ver el detalle',
                      child: GraficoIngresosEgresos(puntos: serie),
                    ),
                    const SizedBox(height: 16),
                    BloqueFinanzas(
                      titulo: 'Salud del negocio',
                      subtitulo: 'Cuatro números para decidir rápido',
                      child: RejillaSalud(items: salud),
                    ),
                    const SizedBox(height: 16),
                    BloqueFinanzas(
                      titulo: 'Prendas más pedidas',
                      subtitulo: 'Qué mueve tu lavandería',
                      child: DesgloseGastos(filas: prendasFilas, dinero: false),
                    ),
                    const SizedBox(height: 16),
                    BloqueFinanzas(
                      titulo: 'En qué se va el dinero',
                      subtitulo: 'Egresos por categoría',
                      child: DesgloseGastos(filas: desglose),
                    ),
                    const SizedBox(height: 16),
                    BloqueFinanzas(
                      titulo: 'Registrar gasto',
                      subtitulo: totalPlanillaMensual > 0
                          ? 'La planilla (${equipo.length} empleado${equipo.length == 1 ? '' : 's'}) se suma sola: -${bs(totalPlanillaPeriodo)} este periodo'
                          : 'Elige una categoría y escribe el monto',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (nombre, icono) in _categoriasGasto)
                            ActionChip(
                              avatar: Icon(
                                icono,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                              label: Text(nombre),
                              onPressed: () => _agregarEgreso(
                                context,
                                ref,
                                lavanderiaId,
                                nombre == 'Otro' ? '' : nombre,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (equipo.any((e) => e.salarioEmpleado == null))
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '⚠ Falta definir el salario de algún empleado: la planilla está incompleta.',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    BloqueFinanzas(
                      titulo: 'Movimientos',
                      subtitulo: '${movimientos.length} en el periodo',
                      child: ListaMovimientos(
                        items: movimientos.take(25).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _generandoInforme
                            ? null
                            : () => _generarInforme(
                                lavanderia: lavanderia,
                                ingresos: ingresos,
                                egresosDelRango: egresosDelRango,
                                totalPlanillaPeriodo: totalPlanillaPeriodo,
                                equipo: equipo,
                                diasEnRango: diasEnRango,
                              ),
                        icon: _generandoInforme
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          _generandoInforme
                              ? 'Generando...'
                              : 'Generar informe para imprimir',
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
