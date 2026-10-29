import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';

/// Cabecera común de todos los paneles: degradado de la marca, avatar,
/// saludo y botón de salir, con entrada animada.
class PanelHeader extends ConsumerWidget {
  final String rol;
  final String subtitulo;
  final IconData icono;
  final List<Widget> extras;
  final Widget? contenidoInferior;
  final VoidCallback? onAvatarTap;

  const PanelHeader({
    super.key,
    required this.rol,
    required this.subtitulo,
    required this.icono,
    this.extras = const [],
    this.contenidoInferior,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final nombre = appUser?.nombre.split(' ').first ?? '';
    final foto = appUser?.fotoBase64 ?? '';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        12,
        18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  backgroundImage: foto.isEmpty
                      ? null
                      : MemoryImage(base64Decode(foto)),
                  child: foto.isEmpty ? Icon(icono, color: Colors.white) : null,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(width: 12),
              Expanded(
                child:
                    Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre.isEmpty ? 'Hola 👋' : 'Hola, $nombre 👋',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 19,
                              ),
                            ),
                            Text(
                              '$rol · $subtitulo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: -0.05, end: 0),
              ),
              ...extras,
              IconButton(
                onPressed: () =>
                    ref.read(authRepositoryProvider).cerrarSesion(),
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Cerrar sesión',
              ),
            ],
          ),
          if (contenidoInferior != null) ...[
            const SizedBox(height: 16),
            contenidoInferior!
                .animate()
                .fadeIn(delay: 150.ms, duration: 400.ms)
                .slideY(begin: 0.15, end: 0),
          ],
        ],
      ),
    );
  }
}

/// Mini tarjeta de dato (ganancias, entregas...) para dentro de la cabecera.
class DatoHeader extends StatelessWidget {
  final String valor;
  final String etiqueta;
  const DatoHeader({super.key, required this.valor, required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Barra de pestañas estilo "píldora" para debajo de la cabecera.
class PestanasPanel extends StatelessWidget implements PreferredSizeWidget {
  final List<Tab> tabs;
  final bool scrollable;
  const PestanasPanel({super.key, required this.tabs, this.scrollable = false});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: TabBar(
          isScrollable: scrollable,
          tabAlignment: scrollable ? TabAlignment.start : null,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(21),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: tabs,
        ),
      ),
    );
  }
}

/// Botón de acción grande con icono; se hunde suavemente al tocarlo.
class AccionRapida extends StatefulWidget {
  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;
  final Color color;
  const AccionRapida({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.color = AppTheme.primary,
  });

  @override
  State<AccionRapida> createState() => _AccionRapidaState();
}

class _AccionRapidaState extends State<AccionRapida> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _presionado = true),
      onTapCancel: () => setState(() => _presionado = false),
      onTapUp: (_) => setState(() => _presionado = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _presionado ? 0.95 : 1,
        duration: 120.ms,
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icono, color: widget.color),
              ),
              const SizedBox(height: 8),
              Text(
                widget.etiqueta,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de acciones rápidas con entrada escalonada.
class FilaAcciones extends StatelessWidget {
  final List<AccionRapida> acciones;
  const FilaAcciones({super.key, required this.acciones});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < acciones.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: acciones[i]
                .animate()
                .fadeIn(delay: (100 + i * 80).ms, duration: 350.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
          ),
        ],
      ],
    );
  }
}

class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String mensaje;
  const EstadoVacio({super.key, required this.icono, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child:
          Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icono,
                      size: 56,
                      color: AppTheme.primary.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      mensaje,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.95, 0.95)),
    );
  }
}

/// Resumen legible de la ropa de un pedido (para que el repartidor
/// estime si puede cargarla).
String resumenCarga(Map<String, int> prendas, String resumenRegular) {
  final partes = [
    for (final e in prendas.entries)
      if (e.value > 0) '${e.value} ${e.key}',
    if (resumenRegular.isNotEmpty) resumenRegular,
  ];
  return partes.isEmpty ? 'Sin detalle de prendas' : partes.join(' · ');
}
