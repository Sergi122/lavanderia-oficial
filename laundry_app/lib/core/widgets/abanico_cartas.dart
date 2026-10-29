import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum EstadoCarta { vacia, activa, llena, ok, error }

class CartaAbanico {
  final String texto;
  final IconData? icono;
  final EstadoCarta estado;
  const CartaAbanico({
    this.texto = '',
    this.icono,
    this.estado = EstadoCarta.vacia,
  });
}

/// Cartas en abanico: todas pivotan sobre un punto bajo el grupo, así UNA sola
/// rotación abre el arco (como el "OTP Deck"). Entran escalonadas, la carta
/// activa brilla y al terminar se voltean a ✓ / ✕ una tras otra.
class AbanicoCartas extends StatelessWidget {
  final List<CartaAbanico> cartas;
  final double anchoCarta;
  final VoidCallback? onTap;
  const AbanicoCartas({
    super.key,
    required this.cartas,
    this.anchoCarta = 54,
    this.onTap,
  });

  static const _hielo = Color(0xFF8FD7FF);
  static const _ok = Color(0xFF3DDC84);
  static const _err = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    final alto = anchoCarta * 1.35;
    final n = cartas.length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth.isFinite ? c.maxWidth : anchoCarta * n * 1.2;
          final paso = ((ancho - anchoCarta) / (n - 1).clamp(1, 99)).clamp(
            0.0,
            anchoCarta * 1.08,
          );
          final total = paso * (n - 1) + anchoCarta;
          final izq = (ancho - total) / 2;
          return SizedBox(
            height: alto + 36,
            width: ancho,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: izq + paso * i,
                    top: 18 + _arco(i, n) * 14,
                    child: Transform.rotate(
                      angle: (i - (n - 1) / 2) * 0.085,
                      alignment: const Alignment(0, 5.5),
                      child: _carta(i, alto),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 0 en el centro, 1 en los extremos: las cartas de las puntas caen un poco.
  double _arco(int i, int n) {
    if (n < 2) return 0;
    final x = (i - (n - 1) / 2) / ((n - 1) / 2);
    return x * x;
  }

  Widget _carta(int i, double alto) {
    final c = cartas[i];
    final color = switch (c.estado) {
      EstadoCarta.ok => _ok,
      EstadoCarta.error => _err,
      EstadoCarta.activa => _hielo,
      EstadoCarta.llena => const Color(0xFF5B9BFF),
      EstadoCarta.vacia => const Color(0xFF2A3F63),
    };
    final resaltada = c.estado != EstadoCarta.vacia;
    final contenido = c.estado == EstadoCarta.ok
        ? const Icon(
            Icons.check_rounded,
            color: _ok,
            size: 30,
            key: ValueKey('ok'),
          )
        : c.estado == EstadoCarta.error
        ? const Icon(
            Icons.close_rounded,
            color: _err,
            size: 28,
            key: ValueKey('err'),
          )
        : c.icono != null
        ? Icon(c.icono, color: Colors.white, size: 26, key: ValueKey(c.icono))
        : Text(
            c.texto,
            key: ValueKey(c.texto),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          );

    return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          width: anchoCarta,
          height: alto,
          transform: Matrix4.identity()
            ..translate(0.0, c.estado == EstadoCarta.activa ? -6.0 : 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF22375C), Color(0xFF111F38)],
            ),
            border: Border.all(
              color: color.withValues(alpha: resaltada ? 0.95 : 0.55),
              width: resaltada ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: resaltada ? 0.45 : 0.0),
                blurRadius: 16,
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (w, a) => ScaleTransition(
              scale: a,
              child: FadeTransition(opacity: a, child: w),
            ),
            child: contenido,
          ),
        )
        .animate(delay: (i * 45).ms)
        .fadeIn(duration: 380.ms)
        .slideY(
          begin: 0.7,
          end: 0,
          duration: 560.ms,
          curve: Curves.easeOutBack,
        );
  }
}

const _iconosFoto = [
  Icons.face_retouching_natural,
  Icons.badge_outlined,
  Icons.compare_arrows_rounded,
  Icons.verified_outlined,
];

/// Animación de espera mientras se verifica la foto: cuatro cartas
/// (selfie → carnet → comparación → resultado) que se encienden en cadena.
class AnimacionVerificacionFoto extends StatefulWidget {
  final String mensaje;

  /// null = comparando; true/false = resultado final.
  final bool? resultado;
  final List<IconData> iconos;
  final String? ayuda;
  const AnimacionVerificacionFoto({
    super.key,
    this.mensaje = 'Comparando tu rostro con el carnet…',
    this.resultado,
    this.iconos = _iconosFoto,
    this.ayuda = 'La primera vez puede tardar hasta un minuto.',
  });

  @override
  State<AnimacionVerificacionFoto> createState() =>
      _AnimacionVerificacionFotoState();
}

class _AnimacionVerificacionFotoState extends State<AnimacionVerificacionFoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1A30), Color(0xFF0A1424)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final activa = (_c.value * 4).floor().clamp(0, 3);
              return AbanicoCartas(
                anchoCarta: 58,
                cartas: [
                  for (var i = 0; i < 4; i++)
                    CartaAbanico(
                      icono: widget.iconos[i],
                      estado: widget.resultado == null
                          ? (i == activa
                                ? EstadoCarta.activa
                                : (i < activa
                                      ? EstadoCarta.llena
                                      : EstadoCarta.vacia))
                          : (widget.resultado!
                                ? EstadoCarta.ok
                                : (i == 3
                                      ? EstadoCarta.error
                                      : EstadoCarta.llena)),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            widget.mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 4),
          if (widget.ayuda != null)
            Text(
              widget.ayuda!,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
