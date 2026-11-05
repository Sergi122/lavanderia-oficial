import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Qué hace la moto en la escena.
enum RolMoto { recogiendo, llevando, devolviendo }

class MotoEscena {
  final RolMoto rol;

  /// 0..1 a lo largo de su tramo. `null` = animación en bucle (no hay GPS).
  final double? progreso;

  /// Casa (0..7) del pedido al que pertenece (panel del admin).
  final int slot;

  /// Llega más rápido a su destino (al cambiar de etapa).
  final bool rapido;
  const MotoEscena(
    this.rol, {
    this.progreso,
    this.slot = 0,
    this.rapido = false,
  });
}

/// Casa de un cliente con pedido activo (3D): su estado decide bolsa/paquete y etiqueta.
class CasaEscena {
  final int slot;

  /// esperandoRepartidor | repartidorCamino | ropaEnCamino | enLavanderia | lavando | lista | devolviendo | entregada | trae
  final String estado;
  final String etiqueta;
  const CasaEscena(this.slot, this.estado, this.etiqueta);
}

/// Todo lo que la escena necesita saber para dibujarse. Cliente (un pedido) y
/// admin (todos los pedidos) usan la misma escena con distintos números.
class EscenaDatos {
  /// Bolsas colgadas en recepción.
  final int colgadas;
  final int lavando;
  final int secando;
  final int listas;

  /// Cliente con ropa en proceso: la misma prenda pasa de lavadora a secadora.
  final bool ciclo;
  final List<MotoEscena> motos;

  /// Paquete limpio esperando en la puerta de la casa (pedido entregado).
  final bool paqueteEnCasa;
  final String nombreLavanderia;

  /// Resalta "tu ropa" (cliente) con un marcador que pulsa.
  final bool destacarMia;

  /// Cámara de la escena 3D: 'auto' | 'general' | 'lavanderia' | 'casa'.
  final String foco;

  /// Casas de clientes (una por pedido) y recorrido largo por la ciudad (sincronizado con el GPS real).
  final List<CasaEscena> casas;
  final bool rutaLarga;

  const EscenaDatos({
    this.colgadas = 0,
    this.lavando = 0,
    this.secando = 0,
    this.listas = 0,
    this.ciclo = false,
    this.motos = const [],
    this.paqueteEnCasa = false,
    this.nombreLavanderia = 'Lavandería',
    this.destacarMia = false,
    this.foco = 'auto',
    this.casas = const [],
    this.rutaLarga = false,
  });
}

const _periodoCiclo = 12.0; // 6 s lavando + 6 s secando
const _periodoMoto = 7.0;

/// Escena isométrica animada: casa, calle con moto repartidora y la lavandería
/// por dentro (recepción, lavadoras, secadoras y mesa de entrega).
class EscenaLavanderia extends StatefulWidget {
  final EscenaDatos datos;
  final double aspectRatio;
  const EscenaLavanderia({
    super.key,
    required this.datos,
    this.aspectRatio = 1.8,
  });

  /// Texto de lo que ocurre ahora mismo con la ropa del cliente (para el chip).
  static String? faseCiclo(EscenaDatos d, double t) {
    if (!d.ciclo) return null;
    return (t % _periodoCiclo) < _periodoCiclo / 2 ? 'Lavando' : 'Secando';
  }

  @override
  State<EscenaLavanderia> createState() => _EscenaLavanderiaState();
}

class _EscenaLavanderiaState extends State<EscenaLavanderia>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _mostrado = <double>[];
  final _roles = <RolMoto>[];
  double _ultimoT = 0;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 84))
          ..addListener(_tick)
          ..repeat();
  }

  void _tick() {
    final t = _ctrl.value * 84;
    final dt = (t - _ultimoT).abs() > 40 ? 0.016 : (t - _ultimoT);
    _ultimoT = t;
    final motos = widget.datos.motos;
    while (_mostrado.length < motos.length) {
      _mostrado.add(0);
      _roles.add(motos[_mostrado.length - 1].rol);
    }
    for (var i = 0; i < motos.length; i++) {
      if (_roles[i] != motos[i].rol) {
        _roles[i] = motos[i].rol;
        _mostrado[i] = 0;
      }
      final objetivo = motos[i].progreso;
      if (objetivo == null) {
        // Bucle: avanza y reinicia, con un respiro al llegar.
        final fase = ((t + i * 2.3) % _periodoMoto) / _periodoMoto;
        _mostrado[i] = Curves.easeInOut.transform(
          (fase / 0.85).clamp(0.0, 1.0),
        );
      } else {
        _mostrado[i] += (objetivo - _mostrado[i]) * (1 - math.exp(-dt * 3));
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDDEEFF), Color(0xFFF4F9FF)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: _EscenaPainter(
                    datos: widget.datos,
                    ctrl: _ctrl,
                    mostrado: _mostrado,
                  ),
                ),
              ),
              if (widget.datos.ciclo)
                Positioned(
                  left: 12,
                  top: 12,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      final fase = EscenaLavanderia.faseCiclo(
                        widget.datos,
                        _ctrl.value * 84,
                      )!;
                      return _ChipFase(texto: fase);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipFase extends StatelessWidget {
  final String texto;
  const _ChipFase({required this.texto});

  @override
  Widget build(BuildContext context) {
    final lavando = texto == 'Lavando';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (lavando ? AppTheme.primary : Colors.deepOrange).withValues(
            alpha: 0.4,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            lavando ? Icons.water_drop : Icons.air,
            size: 16,
            color: lavando ? AppTheme.primary : Colors.deepOrange,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── pintor ─────────────────────────

class _EscenaPainter extends CustomPainter {
  final EscenaDatos datos;
  final AnimationController ctrl;
  final List<double> mostrado;

  _EscenaPainter({
    required this.datos,
    required this.ctrl,
    required this.mostrado,
  }) : super(repaint: ctrl);

  late double a; // media anchura de una unidad isométrica
  late double ox, oy;
  late double t;

  static const _alto = 0.9; // alto de 1 unidad z relativo a `a`

  Offset p(double x, double y, [double z = 0]) =>
      Offset(ox + (x - y) * a, oy + (x + y) * a * 0.5 - z * a * _alto);

  static Color sombra(Color c, double f) =>
      Color.lerp(c, const Color(0xFF0A1C33), 1 - f)!;

  Path _poly(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  void _fill(Canvas c, List<Offset> pts, Color color) =>
      c.drawPath(_poly(pts), Paint()..color = color);

  void caja(
    Canvas c,
    double x0,
    double y0,
    double x1,
    double y1,
    double z0,
    double z1,
    Color col,
  ) {
    _fill(c, [
      p(x1, y0, z0),
      p(x1, y1, z0),
      p(x1, y1, z1),
      p(x1, y0, z1),
    ], sombra(col, 0.78));
    _fill(c, [
      p(x0, y1, z0),
      p(x1, y1, z0),
      p(x1, y1, z1),
      p(x0, y1, z1),
    ], sombra(col, 0.9));
    _fill(c, [p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1)], col);
  }

  /// Dibuja en el plano frontal (y = const) con coordenadas locales (x, z).
  void enCaraY(
    Canvas c,
    double x0,
    double y,
    double z0,
    void Function() dibujar,
  ) {
    final o = p(x0, y, z0);
    c.save();
    c.transform(
      Float64List.fromList([
        a, a * 0.5, 0, 0, //
        0, a * _alto, 0, 0,
        0, 0, 1, 0,
        o.dx, o.dy, 0, 1,
      ]),
    );
    dibujar();
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    t = ctrl.value * 84;
    const ancho = 21.2, alto = 12.4;
    a = math.min(size.width / ancho, size.height / alto);
    ox = size.width / 2 - 0.65 * a;
    oy = (size.height - alto * a) / 2 + 1.9 * a;

    _suelo(canvas);
    _arboles(canvas);
    _casa(canvas);
    _lavanderia(canvas);
    for (var i = 0; i < datos.motos.length; i++) {
      _moto(canvas, datos.motos[i], i < mostrado.length ? mostrado[i] : 0);
    }
  }

  // ── suelo y calle ──
  void _suelo(Canvas c) {
    _fill(c, [
      p(-0.5, -0.5),
      p(10.5, -0.5),
      p(10.5, 9.2),
      p(-0.5, 9.2),
    ], const Color(0xFFE6F1FC));
    // acera
    _fill(c, [
      p(-0.5, 6.7),
      p(10.5, 6.7),
      p(10.5, 7.2),
      p(-0.5, 7.2),
    ], const Color(0xFFD2E1F2));
    // calle
    _fill(c, [
      p(-0.5, 7.2),
      p(10.5, 7.2),
      p(10.5, 8.5),
      p(-0.5, 8.5),
    ], const Color(0xFF5E6E85));
    for (var x = -0.2; x < 10.4; x += 1.4) {
      _fill(c, [
        p(x, 7.8),
        p(x + 0.7, 7.8),
        p(x + 0.7, 7.9),
        p(x, 7.9),
      ], const Color(0xFFE9EEF5));
    }
    _fill(c, [
      p(-0.5, 8.5),
      p(10.5, 8.5),
      p(10.5, 9.2),
      p(-0.5, 9.2),
    ], const Color(0xFFD2E1F2));
  }

  void _arbol(Canvas c, double x, double y, double s) {
    final base = p(x, y);
    c.drawRect(
      Rect.fromCenter(
        center: base.translate(0, -a * 0.25 * s),
        width: a * 0.14 * s,
        height: a * 0.5 * s,
      ),
      Paint()..color = const Color(0xFF8A6A4F),
    );
    final bal = math.sin(t * 1.3 + x) * a * 0.03;
    c.drawCircle(
      base.translate(bal, -a * 0.8 * s),
      a * 0.42 * s,
      Paint()..color = const Color(0xFF4FB286),
    );
    c.drawCircle(
      base.translate(bal - a * 0.14 * s, -a * 0.68 * s),
      a * 0.28 * s,
      Paint()..color = const Color(0xFF6CC79D),
    );
  }

  void _arboles(Canvas c) {
    _arbol(c, 0.2, 2.4, 1.1);
    _arbol(c, 2.6, 0.6, 0.9);
    _arbol(c, 3.0, 5.6, 0.8);
    _arbol(c, 10.1, 6.3, 0.9);
  }

  // ── casa ──
  void _casa(Canvas c) {
    const x0 = 0.5, x1 = 2.5, y0 = 4.6, y1 = 6.4;
    caja(c, x0, y0, x1, y1, 0, 1.2, const Color(0xFFFFF4E0));
    // puerta + ventana en la cara frontal (y = y1)
    enCaraY(c, x0, y1, 0, () {
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0.35, 0, 0.5, -0.75),
          const Radius.circular(0.05),
        ),
        Paint()..color = const Color(0xFF2F7FE0),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(1.15, -0.45, 0.55, -0.4),
          const Radius.circular(0.05),
        ),
        Paint()..color = const Color(0xFFBFE4FF),
      );
    });
    // techo a cuatro aguas
    final apex = p((x0 + x1) / 2, (y0 + y1) / 2, 2.2);
    final e = [
      p(x0 - 0.15, y0 - 0.15, 1.2),
      p(x1 + 0.15, y0 - 0.15, 1.2),
      p(x1 + 0.15, y1 + 0.15, 1.2),
      p(x0 - 0.15, y1 + 0.15, 1.2),
    ];
    c.drawPath(
      _poly([e[3], e[2], apex]),
      Paint()..color = const Color(0xFFE2705A),
    );
    c.drawPath(
      _poly([e[2], e[1], apex]),
      Paint()..color = sombra(const Color(0xFFE2705A), 0.8),
    );
    _etiqueta(c, 'Tu casa', p((x0 + x1) / 2, y1 + 0.2, 2.9), pequeno: true);

    if (datos.paqueteEnCasa) {
      final base = p(1.2, 7.0);
      final rebote = math.sin(t * 3).abs() * a * 0.12;
      _paquete(c, base.translate(0, -rebote), a * 0.6, limpio: true);
      _brillos(c, base.translate(0, -a * 0.6), a * 0.5);
    }
  }

  // ── lavandería por dentro ──
  static const _lx0 = 4.4, _lx1 = 9.7, _ly0 = 0.6, _ly1 = 6.0;

  void _lavanderia(Canvas c) {
    // piso
    _fill(c, [
      p(_lx0, _ly0),
      p(_lx1, _ly0),
      p(_lx1, _ly1),
      p(_lx0, _ly1),
    ], const Color(0xFFF7FBFF));
    // baldosas
    final lin = Paint()
      ..color = const Color(0xFFDCEAF8)
      ..strokeWidth = 1;
    for (var x = _lx0; x <= _lx1 + 0.01; x += 0.9) {
      c.drawLine(p(x, _ly0), p(x, _ly1), lin);
    }
    for (var y = _ly0; y <= _ly1 + 0.01; y += 0.9) {
      c.drawLine(p(_lx0, y), p(_lx1, y), lin);
    }
    // paredes traseras (bajas, para ver el interior)
    caja(
      c,
      _lx0 - 0.15,
      _ly0 - 0.15,
      _lx1 + 0.15,
      _ly0,
      0,
      2.1,
      const Color(0xFFBFD9F5),
    );
    caja(
      c,
      _lx0 - 0.15,
      _ly0 - 0.15,
      _lx0,
      _ly1 + 0.15,
      0,
      2.1,
      const Color(0xFFCFE3F8),
    );
    // ventanas en la pared del fondo
    for (final x in [5.5, 7.4, 9.0]) {
      enCaraY(c, x, _ly0, 1.1, () {
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, -0.7, 0.9, 0.7),
            const Radius.circular(0.06),
          ),
          Paint()..color = const Color(0xFFEAF6FF),
        );
        c.drawRect(
          const Rect.fromLTWH(0, -0.7, 0.9, 0.7),
          Paint()
            ..color = const Color(0xFF8FC3F5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.05,
        );
      });
    }
    // zócalo frontal bajo (borde del local)
    caja(
      c,
      _lx0 - 0.15,
      _ly1,
      _lx1 + 0.15,
      _ly1 + 0.15,
      0,
      0.18,
      const Color(0xFF9CBBDD),
    );
    caja(
      c,
      _lx1,
      _ly0 - 0.15,
      _lx1 + 0.15,
      _ly1 + 0.15,
      0,
      0.18,
      const Color(0xFF9CBBDD),
    );
    _etiqueta(
      c,
      datos.nombreLavanderia,
      p((_lx0 + _lx1) / 2, _ly0, 3.0),
      grande: true,
    );

    // objetos ordenados por profundidad
    final objetos = <(double, void Function())>[
      (7, () => _recepcion(c)),
      (8.9, () => _maquina(c, 6.6, 1.0, 'lavadora', 0)),
      (10.1, () => _maquina(c, 8.0, 1.0, 'lavadora', 1)),
      (10.7, () => _maquina(c, 6.6, 3.0, 'secadora', 0)),
      (11.9, () => _maquina(c, 8.0, 3.0, 'secadora', 1)),
      (10.2, () => _mesa(c)),
    ]..sort((x, y) => x.$1.compareTo(y.$1));
    for (final o in objetos) {
      o.$2();
    }

    // letrero de entrada
    final puerta = p(7.0, _ly1 + 0.45);
    final flecha = math.sin(t * 4) * a * 0.08;
    c.drawPath(
      Path()
        ..moveTo(puerta.dx - a * 0.25, puerta.dy - a * 0.1 + flecha)
        ..lineTo(puerta.dx + a * 0.25, puerta.dy - a * 0.1 + flecha)
        ..lineTo(puerta.dx, puerta.dy + a * 0.22 + flecha)
        ..close(),
      Paint()..color = AppTheme.primary.withValues(alpha: 0.55),
    );
  }

  // ── recepción: riel con bolsas colgadas ──
  void _recepcion(Canvas c) {
    const y = 1.35;
    const x0 = 4.8, x1 = 6.3;
    final poste = Paint()
      ..color = const Color(0xFF7C8DA6)
      ..strokeWidth = a * 0.07
      ..strokeCap = StrokeCap.round;
    c.drawLine(p(x0, y), p(x0, y, 1.9), poste);
    c.drawLine(p(x1, y), p(x1, y, 1.9), poste);
    c.drawLine(p(x0, y, 1.9), p(x1, y, 1.9), poste);
    const colores = [
      Color(0xFF6C8CFF),
      Color(0xFFFF8E72),
      Color(0xFF46C2A5),
      Color(0xFFF2B84B),
      Color(0xFFB98BF2),
      Color(0xFF58B7F0),
    ];
    final n = datos.colgadas.clamp(0, 6);
    for (var i = 0; i < n; i++) {
      final fx = x0 + 0.2 + i * ((x1 - x0 - 0.3) / 5);
      final gancho = p(fx, y, 1.9);
      final sw = math.sin(t * 1.8 + i * 1.3) * a * 0.05;
      c.drawLine(
        gancho,
        gancho.translate(sw * 0.4, a * 0.25),
        poste..strokeWidth = a * 0.03,
      );
      _prenda(
        c,
        gancho.translate(sw, a * 0.25),
        a * 0.5,
        colores[i % colores.length],
      );
    }
    if (datos.destacarMia && n > 0) {
      final mp = p((x0 + x1) / 2, y, 2.9);
      _marcador(c, mp, 'Tu ropa');
    }
  }

  void _prenda(Canvas c, Offset top, double s, Color col) {
    final path = Path()
      ..moveTo(top.dx - s * 0.18, top.dy)
      ..lineTo(top.dx - s * 0.5, top.dy + s * 0.2)
      ..lineTo(top.dx - s * 0.36, top.dy + s * 0.42)
      ..lineTo(top.dx - s * 0.26, top.dy + s * 0.34)
      ..lineTo(top.dx - s * 0.26, top.dy + s * 0.95)
      ..lineTo(top.dx + s * 0.26, top.dy + s * 0.95)
      ..lineTo(top.dx + s * 0.26, top.dy + s * 0.34)
      ..lineTo(top.dx + s * 0.36, top.dy + s * 0.42)
      ..lineTo(top.dx + s * 0.5, top.dy + s * 0.2)
      ..lineTo(top.dx + s * 0.18, top.dy)
      ..quadraticBezierTo(top.dx, top.dy + s * 0.14, top.dx - s * 0.18, top.dy)
      ..close();
    c.drawPath(path, Paint()..color = col);
    c.drawPath(
      path,
      Paint()
        ..color = sombra(col, 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = a * 0.025,
    );
  }

  // ── lavadora / secadora ──
  void _maquina(Canvas c, double x, double y, String tipo, int idx) {
    final esLav = tipo == 'lavadora';
    final bool activa;
    if (datos.ciclo) {
      final lavandoAhora = (t % _periodoCiclo) < _periodoCiclo / 2;
      activa = idx == 0 && (esLav ? lavandoAhora : !lavandoAhora);
    } else {
      activa = idx < (esLav ? datos.lavando : datos.secando);
    }
    final cuerpo = esLav ? const Color(0xFFFFFFFF) : const Color(0xFFF4F1EC);
    const w = 1.1, d = 0.95, h = 1.15;
    caja(c, x, y, x + w, y + d, 0, h, cuerpo);
    // panel + botones sobre la cara frontal
    enCaraY(c, x, y + d, 0, () {
      c.drawRect(
        const Rect.fromLTWH(0, -h + 0.02, w, 0.22),
        Paint()
          ..color = esLav ? const Color(0xFF8FC3F5) : const Color(0xFFF2B27A),
      );
      c.drawCircle(
        const Offset(0.2, -h + 0.13),
        0.05,
        Paint()..color = Colors.white,
      );
      c.drawCircle(
        const Offset(0.38, -h + 0.13),
        0.05,
        Paint()..color = Colors.white,
      );
      c.drawCircle(
        Offset(w - 0.2, -h + 0.13),
        0.05,
        Paint()
          ..color = activa ? const Color(0xFF3DDC84) : const Color(0xFFB8C4D4),
      );
      // ojo de buey
      const cx = w / 2, cy = -0.52;
      c.drawCircle(
        const Offset(cx, cy),
        0.36,
        Paint()..color = const Color(0xFFC9D6E6),
      );
      c.drawCircle(
        const Offset(cx, cy),
        0.3,
        Paint()..color = const Color(0xFF1E3350),
      );
      c.save();
      c.clipPath(
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: 0.3)),
      );
      if (activa) {
        if (esLav) {
          final nivel = cy + 0.08 + math.sin(t * 3) * 0.03;
          c.drawRect(
            Rect.fromLTRB(cx - 0.3, nivel, cx + 0.3, cy + 0.3),
            Paint()..color = const Color(0xFF5BB6FF).withValues(alpha: 0.85),
          );
        } else {
          c.drawCircle(
            const Offset(cx, cy),
            0.3,
            Paint()..color = const Color(0xFFFFB067).withValues(alpha: 0.35),
          );
        }
        final giro = t * (esLav ? 5.0 : 7.5);
        const cols = [
          Color(0xFFFF8E72),
          Color(0xFFF2B84B),
          Color(0xFF6C8CFF),
          Color(0xFF46C2A5),
        ];
        for (var i = 0; i < 4; i++) {
          final ang = giro + i * math.pi / 2;
          c.drawCircle(
            Offset(cx + math.cos(ang) * 0.14, cy + math.sin(ang) * 0.14),
            0.085,
            Paint()..color = cols[i],
          );
        }
      }
      c.restore();
      c.drawCircle(
        const Offset(cx, cy),
        0.3,
        Paint()
          ..color = const Color(0xFF9FB4CC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.03,
      );
    });
    if (activa) {
      final cima = p(x + w / 2, y + d / 2, h);
      if (esLav) {
        for (var i = 0; i < 4; i++) {
          final ph = ((t * 0.7) + i * 0.25) % 1.0;
          c.drawCircle(
            cima.translate(math.sin(ph * 6 + i) * a * 0.3, -ph * a * 0.9),
            a * (0.07 + 0.04 * (i % 2)),
            Paint()
              ..color = const Color(0xFF8FD7FF)
                  .withValues(alpha: (1 - ph) * 0.9),
          );
        }
      } else {
        for (var i = 0; i < 3; i++) {
          final ph = ((t * 0.6) + i * 0.33) % 1.0;
          final path = Path()
            ..moveTo(cima.dx + (i - 1) * a * 0.25, cima.dy - ph * a * 0.9);
          path.relativeCubicTo(
            a * 0.12,
            -a * 0.12,
            -a * 0.12,
            -a * 0.22,
            0,
            -a * 0.34,
          );
          c.drawPath(
            path,
            Paint()
              ..color = const Color(0xFFFF9A5A)
                  .withValues(alpha: (1 - ph) * 0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = a * 0.05
              ..strokeCap = StrokeCap.round,
          );
        }
      }
      if (datos.destacarMia && datos.ciclo) {
        _marcador(c, p(x + w / 2, y + d / 2, h + 1.0), 'Tu ropa');
      }
    }
  }

  // ── mesa de entrega con ropa limpia doblada ──
  void _mesa(Canvas c) {
    const x0 = 4.9, x1 = 6.3, y0 = 3.9, y1 = 5.3;
    caja(c, x0, y0, x1, y1, 0, 0.7, const Color(0xFFE9D8BF));
    final n = datos.listas.clamp(0, 4);
    const cols = [
      Color(0xFF7FB8F5),
      Color(0xFFFFC6A8),
      Color(0xFFB7E3C6),
      Color(0xFFF7E49A),
    ];
    for (var i = 0; i < n; i++) {
      final cx = x0 + 0.35 + (i % 2) * 0.65;
      final cy = y0 + 0.35 + (i ~/ 2) * 0.65;
      for (var k = 0; k < 3; k++) {
        caja(
          c,
          cx - 0.22,
          cy - 0.22,
          cx + 0.22,
          cy + 0.22,
          0.7 + k * 0.1,
          0.78 + k * 0.1,
          cols[(i + k) % cols.length],
        );
      }
    }
    if (n > 0) {
      _brillos(c, p((x0 + x1) / 2, (y0 + y1) / 2, 1.5), a * 0.5);
      if (datos.destacarMia)
        _marcador(c, p((x0 + x1) / 2, (y0 + y1) / 2, 2.2), 'Tu ropa lista');
    }
  }

  // ── moto ──
  void _moto(Canvas c, MotoEscena m, double prog) {
    const xCasa = 1.6, xLav = 7.0, yCarril = 7.85;
    double x;
    int dir;
    switch (m.rol) {
      case RolMoto.recogiendo:
        x = -1.0 + (xCasa + 1.0) * prog;
        dir = 1;
      case RolMoto.llevando:
        x = xCasa + (xLav - xCasa) * prog;
        dir = 1;
      case RolMoto.devolviendo:
        x = xLav - (xLav - xCasa) * prog;
        dir = -1;
    }
    final base = p(x, yCarril);
    final s = a * 0.95;
    final rebote = math.sin(t * 14) * s * 0.012;
    c.save();
    c.translate(base.dx, base.dy + rebote);
    // sombra
    c.drawOval(
      Rect.fromCenter(
        center: Offset(0, s * 0.02),
        width: s * 1.7,
        height: s * 0.28,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    c.rotate(0.4636);
    c.scale(dir.toDouble(), 1);
    c.scale(s);
    final dura = const Color(0xFF1E3350);
    // ruedas
    for (final wx in [-0.55, 0.55]) {
      c.drawCircle(Offset(wx, -0.28), 0.28, Paint()..color = dura);
      c.drawCircle(
        Offset(wx, -0.28),
        0.12,
        Paint()..color = const Color(0xFFC9D6E6),
      );
      final r = t * 22 * dir;
      c.drawLine(
        Offset(wx + math.cos(r) * 0.1, -0.28 + math.sin(r) * 0.1),
        Offset(wx - math.cos(r) * 0.1, -0.28 - math.sin(r) * 0.1),
        Paint()
          ..color = dura
          ..strokeWidth = 0.04,
      );
    }
    // carrocería
    final cuerpo = Path()
      ..moveTo(-0.72, -0.42)
      ..quadraticBezierTo(-0.7, -0.78, -0.3, -0.76)
      ..lineTo(0.2, -0.72)
      ..quadraticBezierTo(0.5, -0.7, 0.62, -0.38)
      ..lineTo(0.3, -0.34)
      ..lineTo(-0.2, -0.3)
      ..close();
    c.drawPath(cuerpo, Paint()..color = AppTheme.primary);
    c.drawLine(
      const Offset(0.5, -0.5),
      const Offset(0.42, -1.05),
      Paint()
        ..color = dura
        ..strokeWidth = 0.07
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      const Offset(0.3, -1.08),
      const Offset(0.52, -1.08),
      Paint()
        ..color = dura
        ..strokeWidth = 0.07
        ..strokeCap = StrokeCap.round,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-0.62, -0.88, 0.62, 0.14),
        const Radius.circular(0.07),
      ),
      Paint()..color = dura,
    );
    // paquete trasero
    final conCarga = m.rol != RolMoto.recogiendo;
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-1.0, -1.36, 0.6, 0.5),
        const Radius.circular(0.06),
      ),
      Paint()
        ..color = conCarga
            ? (m.rol == RolMoto.devolviendo
                  ? Colors.white
                  : const Color(0xFFC49A6C))
            : const Color(0xFF2F7FE0),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-1.0, -1.36, 0.6, 0.5),
        const Radius.circular(0.06),
      ),
      Paint()
        ..color = sombra(const Color(0xFF2F7FE0), 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.03,
    );
    if (m.rol == RolMoto.devolviendo) {
      c.drawCircle(
        const Offset(-0.7, -1.11),
        0.1,
        Paint()..color = const Color(0xFF3DDC84),
      );
    }
    // piloto
    final piel = Paint()..color = const Color(0xFFF2C6A0);
    c.drawLine(
      const Offset(-0.12, -0.82),
      const Offset(-0.02, -1.42),
      Paint()
        ..color = const Color(0xFFFF8E72)
        ..strokeWidth = 0.3
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      const Offset(0.05, -1.25),
      const Offset(0.42, -1.07),
      Paint()
        ..color = const Color(0xFFFF8E72)
        ..strokeWidth = 0.1
        ..strokeCap = StrokeCap.round,
    );
    c.drawCircle(const Offset(0.0, -1.62), 0.17, piel);
    c.drawArc(
      Rect.fromCircle(center: const Offset(0.0, -1.64), radius: 0.2),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFF2B84B),
    );
    // faro
    c.drawCircle(
      const Offset(0.62, -0.62),
      0.07,
      Paint()..color = const Color(0xFFFFF3B0),
    );
    c.restore();
  }

  // ── piezas sueltas ──
  void _paquete(Canvas c, Offset base, double s, {required bool limpio}) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: base.translate(0, -s * 0.5), width: s, height: s),
      Radius.circular(s * 0.12),
    );
    c.drawRRect(
      r,
      Paint()..color = limpio ? Colors.white : const Color(0xFFC49A6C),
    );
    c.drawRRect(
      r,
      Paint()
        ..color = AppTheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.06,
    );
    c.drawLine(
      base.translate(0, -s),
      base.translate(0, 0),
      Paint()
        ..color = AppTheme.primary
        ..strokeWidth = s * 0.06,
    );
  }

  void _brillos(Canvas c, Offset centro, double radio) {
    for (var i = 0; i < 3; i++) {
      final ph = ((t * 0.8) + i / 3) % 1.0;
      final ang = i * 2.1 + 0.6;
      final pos = centro.translate(
        math.cos(ang) * radio * 0.7,
        math.sin(ang) * radio * 0.5 - ph * radio * 0.4,
      );
      final r = radio * 0.16 * math.sin(ph * math.pi);
      final path = Path()
        ..moveTo(pos.dx, pos.dy - r)
        ..lineTo(pos.dx + r * 0.3, pos.dy - r * 0.3)
        ..lineTo(pos.dx + r, pos.dy)
        ..lineTo(pos.dx + r * 0.3, pos.dy + r * 0.3)
        ..lineTo(pos.dx, pos.dy + r)
        ..lineTo(pos.dx - r * 0.3, pos.dy + r * 0.3)
        ..lineTo(pos.dx - r, pos.dy)
        ..lineTo(pos.dx - r * 0.3, pos.dy - r * 0.3)
        ..close();
      c.drawPath(path, Paint()..color = const Color(0xFFFFE27A));
    }
  }

  void _marcador(Canvas c, Offset punta, String texto) {
    final pulso = 1 + math.sin(t * 4) * 0.06;
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          color: Colors.white,
          fontSize: a * 0.52,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: punta.translate(0, -a * 0.55),
        width: tp.width * pulso + a * 0.5,
        height: tp.height + a * 0.26,
      ),
      Radius.circular(a * 0.4),
    );
    c.drawRRect(
      r.shift(Offset(0, a * 0.04)),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
    c.drawRRect(r, Paint()..color = AppTheme.primary);
    c.drawPath(
      Path()
        ..moveTo(punta.dx - a * 0.16, r.bottom - 1)
        ..lineTo(punta.dx + a * 0.16, r.bottom - 1)
        ..lineTo(punta.dx, r.bottom + a * 0.2)
        ..close(),
      Paint()..color = AppTheme.primary,
    );
    tp.paint(
      c,
      Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2),
    );
  }

  void _etiqueta(
    Canvas c,
    String texto,
    Offset centro, {
    bool pequeno = false,
    bool grande = false,
  }) {
    final fs =
        a *
        (grande
            ? 0.62
            : pequeno
            ? 0.4
            : 0.5);
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          color: AppTheme.tinta,
          fontSize: fs,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: a * 9);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: centro,
        width: tp.width + a * 0.5,
        height: tp.height + a * 0.2,
      ),
      Radius.circular(a * 0.3),
    );
    c.drawRRect(r, Paint()..color = Colors.white.withValues(alpha: 0.92));
    tp.paint(
      c,
      Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _EscenaPainter old) => old.datos != datos;
}
