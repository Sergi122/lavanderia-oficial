import '../../../core/widgets/flotante.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../client/data/lavanderia_repository.dart';
import 'hero_demo.dart';
import 'landing_screen_web.dart';
import 'login_screen.dart' show FondoAgua, BotonVidrio;

const _serviciosDestacados = [
  (Icons.local_laundry_service_outlined, 'Lavado y secado'),
  (Icons.iron_outlined, 'Planchado'),
  (Icons.dry_cleaning_outlined, 'Lavado en seco'),
  (Icons.delivery_dining_outlined, 'Recojo y entrega a domicilio'),
];

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const LandingScreenWeb();

    final lavanderiasAsync = ref.watch(lavanderiasProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A1C33),
      body: Stack(
        children: [
          const Positioned.fill(child: FondoAgua()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white,
                            Color(0xFF8FD7FF),
                            Color(0xFF3D8EEB),
                          ],
                          center: Alignment(-.3, -.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.local_laundry_service_rounded,
                        color: Color(0xFF06213F),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Unión de Lavanderías',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text(
                        'Entrar',
                        style: TextStyle(
                          color: Color(0xFF8FD7FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 22),
                const HeroDemo(aspectRatio: 1.0)
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 600.ms)
                    .scale(begin: const Offset(.96, .96)),
                const SizedBox(height: 26),
                const Text(
                  'Tu ropa, en las mejores manos de La Paz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.6,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                const SizedBox(height: 10),
                const Text(
                  'Encuentra lavanderías verificadas cerca de ti, pide recojo a domicilio y mira tu pedido recorrer la ciudad en tiempo real.',
                  style: TextStyle(
                    color: Color(0xCCF3FAFF),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ).animate().fadeIn(delay: 260.ms, duration: 500.ms),
                const SizedBox(height: 22),
                BotonVidrio(
                  onPressed: () => context.go('/login'),
                  child: const Text('Iniciar sesión / Registrarme'),
                ).animate().fadeIn(delay: 320.ms, duration: 500.ms),
                const SizedBox(height: 34),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final s in _serviciosDestacados)
                      Flotante(
                        intensidad: .8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                s.$1,
                                color: const Color(0xFF8FD7FF),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                s.$2,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 34),
                const Text(
                  'Lavanderías de la red',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 14),
                lavanderiasAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (lavanderias) {
                    if (lavanderias.isEmpty) {
                      return const Text(
                        'Muy pronto se unirán las primeras lavanderías.',
                        style: TextStyle(color: Colors.white70),
                      );
                    }
                    return Column(
                      children: [
                        for (final lav in lavanderias.take(5))
                          Flotante(
                            intensidad: .7,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  lav.fotosBase64.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Image.memory(
                                            base64Decode(lav.fotosBase64.first),
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons
                                                .local_laundry_service_outlined,
                                            color: Color(0xFF8FD7FF),
                                          ),
                                        ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lav.nombre,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          lav.direccion,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
