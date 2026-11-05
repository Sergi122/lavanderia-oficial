import '../../../core/widgets/flotante.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/escena_3d/escena_interactiva.dart';
import '../../../core/escena_3d/escena_lavanderia.dart';

/// Demo de bienvenida: la historia completa de un pedido en la ciudad 3D
/// (moto recoge → lavado → secado → listo → vuelve a casa), con subtítulos.
class HeroDemo extends StatefulWidget {
  final double aspectRatio;
  const HeroDemo({super.key, this.aspectRatio = 1.0});

  @override
  State<HeroDemo> createState() => _HeroDemoState();
}

class _HeroDemoState extends State<HeroDemo> {
  static const _n = 'Lavandería Central';
  static const _capitulos = <(String, EscenaDatos, int)>[
    (
      'Tu repartidor va a recoger la ropa',
      EscenaDatos(
        motos: [MotoEscena(RolMoto.recogiendo)],
        nombreLavanderia: _n,
      ),
      5,
    ),
    (
      'Camino a la lavandería, por la ciudad',
      EscenaDatos(motos: [MotoEscena(RolMoto.llevando)], nombreLavanderia: _n),
      10,
    ),
    (
      'Recibida en recepción',
      EscenaDatos(colgadas: 3, destacarMia: true, nombreLavanderia: _n),
      6,
    ),
    (
      'Lavando y secando',
      EscenaDatos(
        ciclo: true,
        lavando: 1,
        colgadas: 2,
        destacarMia: true,
        nombreLavanderia: _n,
      ),
      12,
    ),
    (
      'Ropa limpia, doblada y lista',
      EscenaDatos(
        listas: 3,
        colgadas: 1,
        destacarMia: true,
        nombreLavanderia: _n,
      ),
      6,
    ),
    (
      'Vuelve a tu casa',
      EscenaDatos(
        motos: [MotoEscena(RolMoto.devolviendo)],
        listas: 1,
        nombreLavanderia: _n,
      ),
      10,
    ),
    (
      '¡Entregada en tu puerta!',
      EscenaDatos(paqueteEnCasa: true, nombreLavanderia: _n),
      6,
    ),
  ];

  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _programar();
  }

  void _programar() {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: _capitulos[_i].$3), () {
      if (!mounted) return;
      setState(() => _i = (_i + 1) % _capitulos.length);
      _programar();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cap = _capitulos[_i];
    return Flotante(
      intensidad: .5,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EscenaInteractiva(datos: cap.$2, aspectRatio: widget.aspectRatio),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: 350.ms,
                      child: Text(
                        cap.$1,
                        key: ValueKey(_i),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                  for (var k = 0; k < _capitulos.length; k++)
                    AnimatedContainer(
                      duration: 300.ms,
                      margin: const EdgeInsets.only(left: 4),
                      width: k == _i ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: k == _i
                            ? const Color(0xFF8FD7FF)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
