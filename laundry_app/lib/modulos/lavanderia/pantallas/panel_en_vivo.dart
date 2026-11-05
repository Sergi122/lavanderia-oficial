import '../../../core/widgets/flotante.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/contrato/modelos/pedido.dart';
import '../../../core/escena_3d/escena_datos.dart';
import '../../../core/escena_3d/escena_interactiva.dart';

/// "Tu lavandería en vivo": la escena animada con el estado real de todos los
/// pedidos activos y un contador por etapa.
class PanelEnVivo extends StatefulWidget {
  final List<Pedido> pedidos;
  final String nombreLavanderia;
  final double? lavLat, lavLng;
  final Widget? encima;
  const PanelEnVivo({
    super.key,
    required this.pedidos,
    required this.nombreLavanderia,
    this.lavLat,
    this.lavLng,
    this.encima,
  });

  @override
  State<PanelEnVivo> createState() => _PanelEnVivoState();
}

class _PanelEnVivoState extends State<PanelEnVivo> {
  // cada pedido conserva su casa de cliente en la ciudad mientras esté activo
  final _casas = AsignadorCasas();

  @override
  Widget build(BuildContext context) {
    final pedidos = widget.pedidos;
    final datos = escenaDeLavanderia(
      pedidos,
      widget.nombreLavanderia,
      asignador: _casas,
      lavLat: widget.lavLat,
      lavLng: widget.lavLng,
    );
    final activos = pedidos
        .where(
          (p) => p.estado != EstadoPedido.entregado && !p.entregaCompletada,
        )
        .length;
    final kpis = <(String, int, IconData, Color)>[
      (
        'En recepción',
        datos.colgadas,
        Icons.checkroom_outlined,
        const Color(0xFF6C8CFF),
      ),
      ('Lavando', datos.lavando, Icons.water_drop_outlined, AppTheme.primary),
      ('Secando', datos.secando, Icons.air, Colors.deepOrange),
      (
        'Listos',
        datos.listas,
        Icons.check_circle_outline,
        const Color(0xFF1FA67A),
      ),
      (
        'En ruta',
        datos.motos.length,
        Icons.two_wheeler,
        const Color(0xFF8B5CF6),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tu lavandería en vivo',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1FA67A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1FA67A),
                          shape: BoxShape.circle,
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fade(begin: 0.3, end: 1, duration: 900.ms),
                  const SizedBox(width: 6),
                  Text(
                    '$activos activos',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1FA67A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        EscenaInteractiva(
          aspectRatio: 1.15,
          encima: widget.encima,
          datos: datos,
          mensaje: activos == 0
              ? 'Sin pedidos activos: tu lavandería está lista para el siguiente'
              : null,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kpis.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final k = kpis[i];
              return Flotante(
                intensidad: .8,
                child: Container(
                  width: 112,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: k.$4.withValues(alpha: 0.18)),
                    boxShadow: [
                      BoxShadow(
                        color: k.$4.withValues(alpha: 0.08),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(k.$3, size: 15, color: k.$4),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              k.$1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${k.$2}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: k.$4,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: (i * 70).ms).slideY(begin: 0.2, end: 0);
            },
          ),
        ),
      ],
    );
  }
}
