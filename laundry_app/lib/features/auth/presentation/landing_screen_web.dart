import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import 'hero_demo.dart';
import '../../client/data/lavanderia_repository.dart';
import '../../shared/models/lavanderia.dart';

const _centroLaPaz = LatLng(-16.5000, -68.1500);

const _servicios = [
  (
    Icons.local_laundry_service_rounded,
    'Lavado y secado',
    'Prendas de todos los días, listas en horas y con la calidad de siempre.',
  ),
  (
    Icons.iron_rounded,
    'Planchado',
    'Ropa impecable, doblada y lista para usar apenas la recibas.',
  ),
  (
    Icons.dry_cleaning_rounded,
    'Lavado en seco',
    'Para las prendas que necesitan un cuidado especial y delicado.',
  ),
  (
    Icons.delivery_dining_rounded,
    'Recojo y entrega',
    'Un repartidor verificado pasa por tu ropa y te la devuelve en tu puerta.',
  ),
];

const _pasos = [
  (
    '1',
    'Elegí tu lavandería',
    'Buscá entre las lavanderías verificadas cerca de ti en el mapa.',
  ),
  (
    '2',
    'Pedí recojo a domicilio',
    'Programá el recojo y armá tu pedido en un par de toques.',
  ),
  (
    '3',
    'Seguí tu pedido',
    'Mirá el estado en tiempo real hasta que tu ropa vuelva a tu puerta.',
  ),
];

/// Página de inicio pensada solo para la versión web: layout ancho tipo
/// landing page de producto (nav fija con blur, hero grande, secciones con
/// más aire), a diferencia de `LandingScreen`, que es la versión compacta
/// de una sola columna para el celular.
class LandingScreenWeb extends ConsumerStatefulWidget {
  const LandingScreenWeb({super.key});

  @override
  ConsumerState<LandingScreenWeb> createState() => _LandingScreenWebState();
}

class _LandingScreenWebState extends ConsumerState<LandingScreenWeb> {
  final _scroll = ScrollController();
  final _nosotrosKey = GlobalKey();
  final _serviciosKey = GlobalKey();
  final _comoFuncionaKey = GlobalKey();
  final _lavanderiasKey = GlobalKey();
  bool _navSolido = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final solido = _scroll.offset > 12;
      if (solido != _navSolido) setState(() => _navSolido = solido);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _irA(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lavanderiasAsync = ref.watch(lavanderiasProvider);
    final ancho = MediaQuery.of(context).size.width;
    final esAngosto = ancho < 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                _Hero(
                  esAngosto: esAngosto,
                  onVerLavanderias: () => _irA(_lavanderiasKey),
                ),
                _Seccion(
                  key: _nosotrosKey,
                  child: _SeccionQuienesSomos(esAngosto: esAngosto),
                ),
                _Seccion(
                  key: _serviciosKey,
                  color: const Color(0xFFF6F8FA),
                  child: _SeccionServicios(esAngosto: esAngosto),
                ),
                _Seccion(
                  key: _comoFuncionaKey,
                  child: _SeccionComoFunciona(esAngosto: esAngosto),
                ),
                _Seccion(
                  key: _lavanderiasKey,
                  color: const Color(0xFFF6F8FA),
                  child: _SeccionLavanderias(
                    esAngosto: esAngosto,
                    lavanderiasAsync: lavanderiasAsync,
                  ),
                ),
                _SeccionCta(esAngosto: esAngosto),
                const _Footer(),
              ],
            ),
          ),
          _NavBar(
            solido: _navSolido,
            esAngosto: esAngosto,
            onNosotros: () => _irA(_nosotrosKey),
            onServicios: () => _irA(_serviciosKey),
            onComoFunciona: () => _irA(_comoFuncionaKey),
            onLavanderias: () => _irA(_lavanderiasKey),
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _Seccion({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: child,
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final bool solido;
  final bool esAngosto;
  final VoidCallback onNosotros;
  final VoidCallback onServicios;
  final VoidCallback onComoFunciona;
  final VoidCallback onLavanderias;

  const _NavBar({
    required this.solido,
    required this.esAngosto,
    required this.onNosotros,
    required this.onServicios,
    required this.onComoFunciona,
    required this.onLavanderias,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: solido ? 0.86 : 0),
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: solido ? 0.06 : 0),
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: solido ? 16 : 0,
            sigmaY: solido ? 16 : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.local_laundry_service_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Unión de Lavanderías',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    if (!esAngosto) ...[
                      _NavLink('Nosotros', onNosotros),
                      _NavLink('Servicios', onServicios),
                      _NavLink('Cómo funciona', onComoFunciona),
                      _NavLink('Lavanderías', onLavanderias),
                      const SizedBox(width: 12),
                    ],
                    _BotonPill(
                      texto: 'Iniciar sesión',
                      onTap: () => context.go('/login'),
                      relleno: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String texto;
  final VoidCallback onTap;
  const _NavLink(this.texto, this.onTap);

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: _hover ? Colors.black87 : Colors.black54,
            ),
            child: Text(widget.texto),
          ),
        ),
      ),
    );
  }
}

class _BotonPill extends StatefulWidget {
  final String texto;
  final VoidCallback onTap;
  final bool relleno;
  const _BotonPill({
    required this.texto,
    required this.onTap,
    this.relleno = false,
  });

  @override
  State<_BotonPill> createState() => _BotonPillState();
}

class _BotonPillState extends State<_BotonPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: widget.relleno
                  ? (_hover ? AppTheme.primary : Colors.black)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
              border: widget.relleno ? null : Border.all(color: Colors.black26),
            ),
            child: Text(
              widget.texto,
              style: TextStyle(
                color: widget.relleno ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final bool esAngosto;
  final VoidCallback onVerLavanderias;
  const _Hero({required this.esAngosto, required this.onVerLavanderias});

  @override
  Widget build(BuildContext context) {
    final titulo =
        Text(
              'Tu ropa, en las\nmejores manos de La Paz',
              textAlign: esAngosto ? TextAlign.center : TextAlign.left,
              style: TextStyle(
                fontSize: esAngosto ? 40 : 60,
                fontWeight: FontWeight.w800,
                height: 1.08,
                letterSpacing: -1.2,
                color: Colors.black,
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms)
            .moveY(begin: 16, end: 0, curve: Curves.easeOutCubic);

    final subtitulo = Text(
      'Encontrá lavanderías verificadas cerca tuyo, pedí recojo a domicilio '
      'y seguí tu pedido en tiempo real. Todo desde un mismo lugar.',
      textAlign: esAngosto ? TextAlign.center : TextAlign.left,
      style: const TextStyle(color: Colors.black54, fontSize: 18, height: 1.5),
    ).animate().fadeIn(delay: 120.ms, duration: 500.ms);

    final botones = Wrap(
      alignment: esAngosto ? WrapAlignment.center : WrapAlignment.start,
      spacing: 14,
      runSpacing: 14,
      children: [
        _BotonPill(
          texto: 'Iniciar sesión / Registrarme',
          onTap: () => context.go('/login'),
          relleno: true,
        ),
        _BotonPill(texto: 'Ver lavanderías', onTap: onVerLavanderias),
      ],
    ).animate().fadeIn(delay: 220.ms, duration: 500.ms);

    final stats = Wrap(
      alignment: esAngosto ? WrapAlignment.center : WrapAlignment.start,
      spacing: 28,
      runSpacing: 10,
      children: const [
        _StatMini(
          icono: Icons.verified_rounded,
          texto: 'Lavanderías verificadas',
        ),
        _StatMini(
          icono: Icons.delivery_dining_rounded,
          texto: 'Entrega a domicilio',
        ),
        _StatMini(icono: Icons.lock_outline_rounded, texto: 'Pagos seguros'),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms);

    final columnaTexto = Column(
      crossAxisAlignment: esAngosto
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        titulo,
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: subtitulo,
        ),
        const SizedBox(height: 30),
        botones,
        const SizedBox(height: 34),
        stats,
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, esAngosto ? 140 : 180, 24, 90),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFFBFA), Colors.white],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _OrbeDecorativo(
              color: AppTheme.primary.withValues(alpha: 0.18),
              size: 320,
            ),
          ),
          Positioned(
            top: 60,
            left: -100,
            child: _OrbeDecorativo(
              color: AppTheme.secondary.withValues(alpha: 0.12),
              size: 260,
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: esAngosto
                  ? Column(
                      children: [
                        columnaTexto,
                        const SizedBox(height: 40),
                        const HeroDemo(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 5, child: columnaTexto),
                        const SizedBox(width: 40),
                        const Expanded(flex: 6, child: HeroDemo()),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbeDecorativo extends StatelessWidget {
  final Color color;
  final double size;
  const _OrbeDecorativo({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(width: size, height: size, color: color),
        ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _StatMini({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 18, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

const _valoresNosotros = [
  (
    Icons.verified_user_rounded,
    'Identidad verificada',
    'Cada lavandería, empleado y repartidor pasa por un carnet + selfie en vivo antes de entrar a la red.',
  ),
  (
    Icons.location_on_rounded,
    'Pensada para La Paz',
    'Cobertura local, con lavanderías reales de la ciudad, no una cadena genérica.',
  ),
  (
    Icons.support_agent_rounded,
    'Seguimiento en vivo',
    'Sabés en qué paso está tu pedido desde que lo recogen hasta que vuelve a tu puerta.',
  ),
];

class _SeccionQuienesSomos extends ConsumerWidget {
  final bool esAngosto;
  const _SeccionQuienesSomos({required this.esAngosto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lavanderiasAsync = ref.watch(lavanderiasProvider);
    final fotos =
        lavanderiasAsync.valueOrNull
            ?.expand((l) => l.fotosBase64)
            .take(4)
            .toList() ??
        const <String>[];

    final texto = Column(
      crossAxisAlignment: esAngosto
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          'Quiénes somos',
          textAlign: esAngosto ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 32,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Somos Los Asustadores, un equipo boliviano armando la red de lavanderías '
            'más confiable de La Paz. Conectamos lavanderías de barrio con quienes '
            'necesitan lavar ropa sin perder tiempo, y verificamos con documento y '
            'selfie en vivo a cada lavandería, empleado y repartidor antes de '
            'sumarlos — así sabés exactamente quién está lavando tu ropa o tocando '
            'la puerta de tu casa.',
            textAlign: esAngosto ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 16,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 28),
        for (final v in _valoresNosotros)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6F6),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(v.$1, color: AppTheme.primary, size: 19),
                ),
                const SizedBox(width: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        v.$3,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ).animate().fadeIn(duration: 450.ms).moveY(begin: 14, end: 0);

    final collage = _CollageFotos(fotos: fotos)
        .animate()
        .fadeIn(delay: 150.ms, duration: 500.ms)
        .scale(begin: const Offset(0.94, 0.94));

    if (esAngosto) {
      return Column(
        children: [
          texto,
          const SizedBox(height: 36),
          SizedBox(height: 320, child: collage),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: texto),
        const SizedBox(width: 56),
        Expanded(child: SizedBox(height: 380, child: collage)),
      ],
    );
  }
}

/// Bento-grid con fotos reales de lavanderías de la red (cuando hay); si no
/// hay suficientes fotos todavía, rellena con bloques de color decorativos.
class _CollageFotos extends StatelessWidget {
  final List<String> fotos;
  const _CollageFotos({required this.fotos});

  Widget _bloque(int i, {required double radius}) {
    if (i < fotos.length) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          base64Decode(fotos[i]),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }
    final colores = [AppTheme.primary, AppTheme.secondary];
    return Container(
      decoration: BoxDecoration(
        color: colores[i % colores.length].withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.local_laundry_service_rounded,
        color: colores[i % colores.length].withValues(alpha: 0.5),
        size: 40,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(flex: 3, child: _bloque(0, radius: 24)),
              const SizedBox(height: 16),
              Expanded(flex: 2, child: _bloque(1, radius: 24)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              Expanded(flex: 2, child: _bloque(2, radius: 24)),
              const SizedBox(height: 16),
              Expanded(flex: 3, child: _bloque(3, radius: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeccionServicios extends StatelessWidget {
  final bool esAngosto;
  const _SeccionServicios({required this.esAngosto});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Lo que ofrecemos',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 32,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Todo lo que tu ropa necesita, con lavanderías verificadas de la red.',
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
        const SizedBox(height: 44),
        GridView.count(
          crossAxisCount: esAngosto ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          childAspectRatio: esAngosto ? 2.6 : 2.4,
          children: [
            for (var i = 0; i < _servicios.length; i++)
              _TarjetaServicio(
                    icono: _servicios[i].$1,
                    titulo: _servicios[i].$2,
                    descripcion: _servicios[i].$3,
                  )
                  .animate()
                  .fadeIn(delay: (80 * i).ms, duration: 400.ms)
                  .moveY(begin: 12, end: 0),
          ],
        ),
      ],
    );
  }
}

class _TarjetaServicio extends StatefulWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  const _TarjetaServicio({
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });

  @override
  State<_TarjetaServicio> createState() => _TarjetaServicioState();
}

class _TarjetaServicioState extends State<_TarjetaServicio> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(widget.icono, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.descripcion,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.4,
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

class _SeccionComoFunciona extends StatelessWidget {
  final bool esAngosto;
  const _SeccionComoFunciona({required this.esAngosto});

  @override
  Widget build(BuildContext context) {
    final pasos = [
      for (var i = 0; i < _pasos.length; i++)
        Expanded(
          child:
              _TarjetaPaso(
                    numero: _pasos[i].$1,
                    titulo: _pasos[i].$2,
                    texto: _pasos[i].$3,
                  )
                  .animate()
                  .fadeIn(delay: (100 * i).ms, duration: 400.ms)
                  .moveY(begin: 14, end: 0),
        ),
    ];

    return Column(
      children: [
        const Text(
          'Cómo funciona',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 32,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Tres pasos y listo.',
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
        const SizedBox(height: 44),
        esAngosto
            ? Column(
                children: [
                  for (var i = 0; i < _pasos.length; i++) ...[
                    _TarjetaPaso(
                      numero: _pasos[i].$1,
                      titulo: _pasos[i].$2,
                      texto: _pasos[i].$3,
                    ),
                    if (i != _pasos.length - 1) const SizedBox(height: 16),
                  ],
                ],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < pasos.length; i++) ...[
                      pasos[i],
                      if (i != pasos.length - 1) const SizedBox(width: 18),
                    ],
                  ],
                ),
              ),
      ],
    );
  }
}

class _TarjetaPaso extends StatelessWidget {
  final String numero;
  final String titulo;
  final String texto;
  const _TarjetaPaso({
    required this.numero,
    required this.titulo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              numero,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionLavanderias extends StatefulWidget {
  final bool esAngosto;
  final AsyncValue<List<Lavanderia>> lavanderiasAsync;
  const _SeccionLavanderias({
    required this.esAngosto,
    required this.lavanderiasAsync,
  });

  @override
  State<_SeccionLavanderias> createState() => _SeccionLavanderiasState();
}

class _SeccionLavanderiasState extends State<_SeccionLavanderias> {
  final _mapController = MapController();
  final _mapaKey = GlobalKey();
  String? _seleccionadaId;

  bool get esAngosto => widget.esAngosto;
  AsyncValue<List<Lavanderia>> get lavanderiasAsync => widget.lavanderiasAsync;

  /// Al hacer clic en una lavandería de la lista, el mapa vuela a su punto y
  /// la pantalla sube hasta el mapa para que se vea.
  void _irALavanderia(Lavanderia lav) {
    if (lav.lat == 0 && lav.lng == 0) return;
    setState(() => _seleccionadaId = lav.id);
    _mapController.move(LatLng(lav.lat, lav.lng), 16);
    final contexto = _mapaKey.currentContext;
    if (contexto != null) {
      Scrollable.ensureVisible(
        contexto,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Lavanderías de la red',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 32,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Verificadas y listas para recibir tu pedido.',
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
        const SizedBox(height: 44),
        lavanderiasAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (lavanderias) {
            if (lavanderias.isEmpty) {
              return const Text(
                'Muy pronto se unirán las primeras lavanderías.',
                style: TextStyle(color: Colors.black54),
              );
            }
            return Column(
              children: [
                _MapaLavanderias(
                  key: _mapaKey,
                  lavanderias: lavanderias,
                  esAngosto: esAngosto,
                  controller: _mapController,
                  seleccionadaId: _seleccionadaId,
                  onSeleccionar: _irALavanderia,
                ),
                const SizedBox(height: 36),
                Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final lav in lavanderias.take(6))
                      SizedBox(
                        width: esAngosto ? double.infinity : 350,
                        child: _TarjetaLavanderia(
                          lavanderia: lav,
                          seleccionada: lav.id == _seleccionadaId,
                          onTap: () => _irALavanderia(lav),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MapaLavanderias extends StatelessWidget {
  final List<Lavanderia> lavanderias;
  final bool esAngosto;
  final MapController controller;
  final String? seleccionadaId;
  final ValueChanged<Lavanderia> onSeleccionar;
  const _MapaLavanderias({
    super.key,
    required this.lavanderias,
    required this.esAngosto,
    required this.controller,
    required this.seleccionadaId,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final ubicadas = lavanderias
        .where((l) => l.lat != 0 || l.lng != 0)
        .toList();
    final centro = ubicadas.isEmpty
        ? _centroLaPaz
        : LatLng(
            ubicadas.map((l) => l.lat).reduce((a, b) => a + b) /
                ubicadas.length,
            ubicadas.map((l) => l.lng).reduce((a, b) => a + b) /
                ubicadas.length,
          );

    return Container(
      height: esAngosto ? 320 : 440,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: centro,
          initialZoom: ubicadas.isEmpty ? 12 : 12.5,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.losasustadores.laundry_app',
          ),
          MarkerLayer(
            markers: [
              for (final lav in ubicadas)
                Marker(
                  point: LatLng(lav.lat, lav.lng),
                  width: lav.id == seleccionadaId ? 54 : 40,
                  height: lav.id == seleccionadaId ? 54 : 40,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => onSeleccionar(lav),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: lav.id == seleccionadaId
                            ? Colors.redAccent
                            : AppTheme.primary,
                        size: lav.id == seleccionadaId ? 54 : 40,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms);
  }
}

class _TarjetaLavanderia extends StatelessWidget {
  final Lavanderia lavanderia;
  final bool seleccionada;
  final VoidCallback? onTap;
  const _TarjetaLavanderia({
    required this.lavanderia,
    this.seleccionada = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: _contenido()),
    );
  }

  Widget _contenido() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: seleccionada
              ? AppTheme.primary
              : Colors.black.withValues(alpha: 0.06),
          width: seleccionada ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          lavanderia.fotosBase64.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    base64Decode(lavanderia.fotosBase64.first),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_laundry_service_outlined,
                    color: AppTheme.primary,
                  ),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lavanderia.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  lavanderia.direccion,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (lavanderia.entregaDomicilio) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6F6),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Entrega a domicilio',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionCta extends StatelessWidget {
  final bool esAngosto;
  const _SeccionCta({required this.esAngosto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: esAngosto ? 28 : 56,
              vertical: esAngosto ? 40 : 56,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Flex(
              direction: esAngosto ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: esAngosto
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: esAngosto ? 0 : 1,
                  child: Column(
                    crossAxisAlignment: esAngosto
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Tenés tu propia lavandería\no una moto para repartir?',
                        textAlign: esAngosto
                            ? TextAlign.center
                            : TextAlign.left,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Unite a la red y empezá a recibir pedidos.',
                        textAlign: esAngosto
                            ? TextAlign.center
                            : TextAlign.left,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: esAngosto ? 24 : 0, width: esAngosto ? 0 : 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _BotonPill(
                    texto: 'Únete a la red',
                    onTap: () => context.go('/login'),
                    relleno: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Text(
          'Los Asustadores © 2026',
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
