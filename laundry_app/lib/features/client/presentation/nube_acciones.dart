import '../../../core/widgets/flotante.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AccionNube {
  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;
  final bool principal;
  const AccionNube(
    this.icono,
    this.etiqueta,
    this.onTap, {
    this.principal = false,
  });
}

/// Nube flotante sobre la ciudad 3D con los accesos del cliente (nuevo pedido, perfil…).
class NubeAcciones extends StatelessWidget {
  final List<AccionNube> acciones;
  const NubeAcciones({super.key, required this.acciones});

  @override
  Widget build(BuildContext context) => Flotante(child: _contenido(context));

  Widget _contenido(BuildContext context) {
    return SizedBox(
      height: 122,
      child: CustomPaint(
        painter: _NubePainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 30, 10, 10),
          child: Row(
            children: [
              for (final a in acciones)
                Expanded(
                  child: Semantics(
                    button: true,
                    label: a.etiqueta,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: a.onTap,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: a.principal ? 46 : 40,
                            height: a.principal ? 46 : 40,
                            decoration: BoxDecoration(
                              color: a.principal
                                  ? AppTheme.primary
                                  : AppTheme.primary.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                              boxShadow: a.principal
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              a.icono,
                              size: a.principal ? 24 : 21,
                              color: a.principal
                                  ? Colors.white
                                  : AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            a.etiqueta,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.1,
                              fontWeight: a.principal
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: AppTheme.tinta,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NubePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // cuerpo + bultos de nube en el borde superior
    var nube = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 34, w, h - 34),
          const Radius.circular(0),
        ),
      );
    final bultos = <(double, double, double)>[
      (.10, 38, 26),
      (.24, 24, 34),
      (.42, 18, 40),
      (.60, 22, 36),
      (.77, 30, 30),
      (.92, 40, 24),
    ];
    for (final (fx, cy, r) in bultos) {
      nube = Path.combine(
        PathOperation.union,
        nube,
        Path()..addOval(Rect.fromCircle(center: Offset(w * fx, cy), radius: r)),
      );
    }
    canvas.drawShadow(nube, Colors.black.withValues(alpha: 0.35), 10, false);
    canvas.drawPath(
      nube,
      Paint()..color = Colors.white.withValues(alpha: 0.96),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
