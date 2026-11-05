import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'escena_3d.dart';
import 'escena_lavanderia.dart';

/// Ciudad 3D con modo "Explorar": arrastrar para girar, pellizcar / rueda para acercar.
/// Apagado por defecto para no bloquear el scroll de la página. [encima] se dibuja
/// flotando sobre la escena (p. ej. la nube de botones del cliente).
class EscenaInteractiva extends StatefulWidget {
  final EscenaDatos datos;
  final String?
  mensaje; // texto flotante arriba a la izquierda (estado de espera, etc.)
  final double aspectRatio;
  final Widget? encima;
  const EscenaInteractiva({
    super.key,
    required this.datos,
    this.mensaje,
    this.aspectRatio = 1.8,
    this.encima,
  });

  @override
  State<EscenaInteractiva> createState() => _EscenaInteractivaState();
}

class _EscenaInteractivaState extends State<EscenaInteractiva> {
  bool _explorar = false;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Escena3DView(
              datos: widget.datos,
              explorar: _explorar,
              aspectRatio: widget.aspectRatio,
            ),
            if (widget.mensaje != null && !_explorar)
              Positioned(
                left: 12,
                top: 12,
                right: 110,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.93),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.mensaje!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 10,
              top: 10,
              child: Material(
                color: _explorar
                    ? AppTheme.primary
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _explorar = !_explorar),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _explorar ? Icons.check : Icons.open_with,
                          size: 15,
                          color: _explorar ? Colors.white : AppTheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _explorar ? 'Listo' : 'Explorar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _explorar ? Colors.white : AppTheme.tinta,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.encima != null && !_explorar)
              Positioned(left: 0, right: 0, bottom: 0, child: widget.encima!),
          ],
        ),
      ),
    );
  }
}
