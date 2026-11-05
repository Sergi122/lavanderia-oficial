import 'dart:convert';

import '../../../core/widgets/flotante.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';

const colIngreso = Color(0xFF1FA67A);
const colEgreso = Color(0xFFE5484D);

String bs(double v, {bool signo = false}) {
  final neg = v < 0;
  final n = v.abs();
  final txt = n >= 10000
      ? n.round().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ' ',
        )
      : n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2);
  return '${neg
      ? '-'
      : signo
      ? '+'
      : ''}Bs $txt';
}

class PuntoSerie {
  final String etiqueta;
  final double ingresos;
  final double egresos;
  const PuntoSerie(this.etiqueta, this.ingresos, this.egresos);
}

/// Tarjeta principal: balance del periodo y comparación con el anterior.
class TarjetaBalance extends StatelessWidget {
  final double balance;
  final double ingresos;
  final double egresos;
  final double?
  variacion; // % del balance vs periodo anterior (null = sin base)
  final String periodo;
  const TarjetaBalance({
    super.key,
    required this.balance,
    required this.ingresos,
    required this.egresos,
    required this.variacion,
    required this.periodo,
  });

  @override
  Widget build(BuildContext context) => Flotante(child: _contenido(context));

  Widget _contenido(BuildContext context) {
    final margen = ingresos > 0 ? (balance / ingresos * 100) : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2A4A), Color(0xFF1E5FB8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Balance neto',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Text(
                periodo,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(end: balance),
            duration: 700.ms,
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              bs(v),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (variacion != null)
                _Pastilla(
                  icono: variacion! >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  texto:
                      '${variacion! >= 0 ? '+' : ''}${variacion!.toStringAsFixed(0)}% vs. periodo anterior',
                  color: variacion! >= 0
                      ? const Color(0xFF6EE7B7)
                      : const Color(0xFFFCA5A5),
                ),
              if (margen != null)
                _Pastilla(
                  icono: Icons.percent,
                  texto: 'Margen ${margen.toStringAsFixed(0)}%',
                  color: Colors.white70,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Mini(
                  icono: Icons.south_west,
                  etiqueta: 'Ingresos',
                  valor: ingresos,
                  color: const Color(0xFF6EE7B7),
                ),
              ),
              Container(width: 1, height: 38, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: _Mini(
                  icono: Icons.north_east,
                  etiqueta: 'Egresos',
                  valor: egresos,
                  color: const Color(0xFFFCA5A5),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }
}

class _Pastilla extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  const _Pastilla({
    required this.icono,
    required this.texto,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          texto,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Mini extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final double valor;
  final Color color;
  const _Mini({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icono, size: 16, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            Text(
              bs(valor),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Fila de indicadores secundarios (pedidos, ticket promedio, por cobrar).
class FilaIndicadores extends StatelessWidget {
  final List<(String, String, IconData)> items;
  const FilaIndicadores({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(items[i].$3, size: 18, color: AppTheme.primary),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      items[i].$2,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    items[i].$1,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 120.ms);
  }
}

/// Contenedor estándar de cada bloque de la pantalla.
class BloqueFinanzas extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget? accion;
  final Widget child;
  const BloqueFinanzas({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.accion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Flotante(child: _contenido(context));

  Widget _contenido(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              if (accion != null) accion!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Barras agrupadas ingresos vs egresos, con ejes y valor al tocar.
class GraficoIngresosEgresos extends StatefulWidget {
  final List<PuntoSerie> puntos;
  const GraficoIngresosEgresos({super.key, required this.puntos});

  @override
  State<GraficoIngresosEgresos> createState() => _GraficoState();
}

class _GraficoState extends State<GraficoIngresosEgresos> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final vacio = widget.puntos.every((p) => p.ingresos == 0 && p.egresos == 0);
    if (vacio) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Aún no hay movimientos en este periodo.',
            style: TextStyle(color: Colors.black45),
          ),
        ),
      );
    }
    final sel = _sel != null && _sel! < widget.puntos.length
        ? widget.puntos[_sel!]
        : null;
    return Column(
      children: [
        SizedBox(
          height: 10 + 24,
          child: sel == null
              ? Row(
                  children: const [
                    _Leyenda(color: colIngreso, texto: 'Ingresos'),
                    SizedBox(width: 14),
                    _Leyenda(color: colEgreso, texto: 'Egresos'),
                  ],
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${sel.etiqueta}:  ${bs(sel.ingresos)} ingresos · ${bs(sel.egresos)} egresos',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        SizedBox(
          height: 190,
          child: LayoutBuilder(
            builder: (context, c) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  const izq = 44.0;
                  final w = (c.maxWidth - izq) / widget.puntos.length;
                  final i = ((d.localPosition.dx - izq) / w).floor();
                  setState(
                    () => _sel = i >= 0 && i < widget.puntos.length && i != _sel
                        ? i
                        : null,
                  );
                },
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: 700.ms,
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => CustomPaint(
                    size: Size(c.maxWidth, 190),
                    painter: _GraficoPainter(widget.puntos, v, _sel),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;
  const _Leyenda({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ],
  );
}

class _GraficoPainter extends CustomPainter {
  final List<PuntoSerie> puntos;
  final double anim;
  final int? sel;
  _GraficoPainter(this.puntos, this.anim, this.sel);

  static double _techo(double max) {
    if (max <= 0) return 1;
    final e = math.pow(10, (math.log(max) / math.ln10).floor()).toDouble();
    for (final m in [1, 2, 2.5, 5, 10]) {
      if (m * e >= max) return m * e;
    }
    return 10 * e;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const izq = 44.0, abajo = 22.0;
    final alto = size.height - abajo;
    final maxV = puntos.fold<double>(
      0,
      (m, p) => math.max(m, math.max(p.ingresos, p.egresos)),
    );
    final techo = _techo(maxV);
    final linea = Paint()
      ..color = const Color(0xFFE3ECF6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = alto - alto * i / 4;
      canvas.drawLine(Offset(izq, y), Offset(size.width, y), linea);
      final v = techo * i / 4;
      final tp = TextPainter(
        text: TextSpan(
          text: v >= 1000
              ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k'
              : v.toStringAsFixed(0),
          style: const TextStyle(fontSize: 10.5, color: Colors.black45),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(izq - 8 - tp.width, y - tp.height / 2));
    }
    final w = (size.width - izq) / puntos.length;
    final paso = (puntos.length / 7).ceil();
    for (var i = 0; i < puntos.length; i++) {
      final p = puntos[i];
      final x = izq + w * i;
      final bw = math.min(w * 0.30, 16.0);
      if (sel == i) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 1, 0, w - 2, alto),
            const Radius.circular(6),
          ),
          Paint()..color = AppTheme.primary.withValues(alpha: 0.07),
        );
      }
      void barra(double v, double dx, Color c) {
        final h = (v / techo) * alto * anim;
        if (h <= 0) return;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x + dx, alto - h, bw, h),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = c,
        );
      }

      barra(p.ingresos, w / 2 - bw - 1, colIngreso);
      barra(p.egresos, w / 2 + 1, colEgreso);
      if (i % paso == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: p.etiqueta,
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: w * paso);
        tp.paint(canvas, Offset(x + w / 2 - tp.width / 2, alto + 5));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraficoPainter old) =>
      old.puntos != puntos || old.anim != anim || old.sel != sel;
}

/// Gastos por categoría con barra proporcional.
class DesgloseGastos extends StatelessWidget {
  final List<(String, double, IconData)> filas; // ya ordenadas desc
  final bool dinero; // false = unidades (prendas)
  const DesgloseGastos({super.key, required this.filas, this.dinero = true});

  @override
  Widget build(BuildContext context) {
    final total = filas.fold<double>(0, (a, f) => a + f.$2);
    if (total <= 0) {
      return const Text(
        'Sin gastos en este periodo.',
        style: TextStyle(color: Colors.black45),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < filas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(filas[i].$3, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        filas[i].$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    Text(
                      bs(filas[i].$2),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${(filas[i].$2 / total * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: filas[i].$2 / total),
                    duration: 600.ms,
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFEAF1F9),
                      color: AppTheme.primary.withValues(
                        alpha: 1 - i * 0.12 > 0.35 ? 1 - i * 0.12 : 0.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class Movimiento {
  final String titulo;
  final String detalle;
  final double monto; // + ingreso, − egreso
  final DateTime? fecha;
  final String adjuntoBase64;
  const Movimiento(
    this.titulo,
    this.detalle,
    this.monto,
    this.fecha, {
    this.adjuntoBase64 = '',
  });
}

class ListaMovimientos extends StatelessWidget {
  final List<Movimiento> items;
  const ListaMovimientos({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'Sin movimientos en este periodo.',
        style: TextStyle(color: Colors.black45),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: Color(0xFFEEF3F9)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (items[i].monto >= 0 ? colIngreso : colEgreso)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    items[i].monto >= 0 ? Icons.south_west : Icons.north_east,
                    size: 17,
                    color: items[i].monto >= 0 ? colIngreso : colEgreso,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        [
                          if (items[i].fecha != null)
                            '${items[i].fecha!.day.toString().padLeft(2, '0')}/${items[i].fecha!.month.toString().padLeft(2, '0')}',
                          items[i].detalle,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (items[i].adjuntoBase64.isNotEmpty)
                  IconButton(
                    tooltip: 'Ver factura',
                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (c) => Dialog(
                        child: InteractiveViewer(
                          child: Image.memory(
                            base64Decode(items[i].adjuntoBase64),
                          ),
                        ),
                      ),
                    ),
                  ),
                Text(
                  bs(items[i].monto, signo: true),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: items[i].monto >= 0 ? colIngreso : colEgreso,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Indicadores de salud del negocio: cada uno con una lectura corta ("va bien" / "atención").
class IndicadorSalud {
  final String titulo, valor, lectura;
  final IconData icono;
  final Color color;
  const IndicadorSalud(
    this.titulo,
    this.valor,
    this.lectura,
    this.icono,
    this.color,
  );
}

class RejillaSalud extends StatelessWidget {
  final List<IndicadorSalud> items;
  const RejillaSalud({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final i in items)
              Container(
                width: ancho,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: i.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: i.color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(i.icono, size: 16, color: i.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            i.titulo,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        i.valor,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: i.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      i.lectura,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black54,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
