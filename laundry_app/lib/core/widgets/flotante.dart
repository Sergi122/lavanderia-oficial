import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Envuelve cualquier widget con un flotar suave y, al pasar el cursor o tocar, una pequeña
/// inclinación 3D hacia donde apunta el dedo/mouse (y se eleva un poco). No captura los toques:
/// el hijo sigue recibiendo sus clics y el scroll de la lista no se bloquea.
class Flotante extends StatefulWidget {
  final Widget child;
  final double intensidad;
  final bool flotar;
  const Flotante({
    super.key,
    required this.child,
    this.intensidad = 1,
    this.flotar = true,
  });

  @override
  State<Flotante> createState() => _FlotanteState();
}

class _FlotanteState extends State<Flotante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 4200 + (identityHashCode(this) % 1800)),
  );
  Offset _p = Offset.zero; // -1..1 respecto al centro
  bool _sobre = false;

  @override
  void initState() {
    super.initState();
    if (widget.flotar &&
        !WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations) {
      _idle.value = (identityHashCode(this) % 100) / 100;
      _idle.repeat();
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  void _apuntar(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    final s = box.size;
    setState(() {
      _p = Offset(
        (((local.dx / s.width) - .5) * 2).clamp(-1.0, 1.0),
        (((local.dy / s.height) - .5) * 2).clamp(-1.0, 1.0),
      );
      _sobre = true;
    });
  }

  void _soltar() => setState(() {
    _p = Offset.zero;
    _sobre = false;
  });

  @override
  Widget build(BuildContext context) {
    final k = widget.intensidad;
    return MouseRegion(
      onHover: (e) => _apuntar(e.localPosition),
      onExit: (_) => _soltar(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _apuntar(e.localPosition),
        onPointerMove: (e) => _apuntar(e.localPosition),
        onPointerUp: (_) => _soltar(),
        onPointerCancel: (_) => _soltar(),
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(end: _p),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          builder: (context, p, child) => AnimatedBuilder(
            animation: _idle,
            builder: (context, _) {
              final bob = math.sin(_idle.value * 2 * math.pi) * 3 * k;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..translateByDouble(0, bob - (_sobre ? 4 * k : 0), 0, 1)
                  ..rotateX(-p.dy * .07 * k)
                  ..rotateY(p.dx * .09 * k)
                  ..scaleByDouble(_sobre ? 1.015 : 1, _sobre ? 1.015 : 1, 1, 1),
                child: child,
              );
            },
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
