import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/arranque/modulo.dart';
import 'core/notifications/background_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/sesion/auth_repository.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'modulos/cuentas/datos/codigo_correo_api.dart';
import 'modulos/cuentas/modulo_cuentas.dart';

/// Arranque común. main.dart lo llama con los diez módulos; cada
/// `main_<modulo>.dart` con el suyo (S1 cuentas entra siempre: es el login).
Future<void> arrancarApp(List<Modulo> modulos, {Modulo? presentado}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await configurarServicioSegundoPlano();
  // Despierta el servidor de códigos/verificación (Render gratis se duerme).
  unawaited(CodigoCorreoApi.despertar());
  // S1 entra siempre, salvo que ya venga una versión que lo incluya
  // (por ejemplo el arranque de octubre de Luis, id 'cuentas_octubre').
  final traeCuentas = modulos.any((m) => m.id.startsWith('cuentas'));
  final activos = traeCuentas ? modulos : [moduloCuentas, ...modulos];
  runApp(
    ProviderScope(
      overrides: [
        modulosActivosProvider.overrideWithValue(activos),
        moduloPresentadoProvider.overrideWithValue(presentado),
      ],
      child: const LaundryApp(),
    ),
  );
}

class LaundryApp extends ConsumerWidget {
  const LaundryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final presentado = ref.watch(moduloPresentadoProvider);

    // Prende el servicio de notificaciones en segundo plano apenas hay sesión
    // iniciada, y lo apaga al cerrar sesión. Sin esto no hay push de ningún tipo.
    ref.listen(authStateProvider, (previo, actual) {
      final user = actual.valueOrNull;
      if (user != null) {
        NotificationService.instance.pedirPermiso();
        iniciarServicioSegundoPlano();
      } else {
        detenerServicioSegundoPlano();
      }
    });

    return MaterialApp.router(
      title: presentado == null
          ? 'Lavandería App'
          : 'Lavandería · ${presentado.etiqueta}',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: presentado == null
          ? null
          : (context, child) => Stack(
              children: [
                child ?? const SizedBox.shrink(),
                _EtiquetaModulo(modulo: presentado, router: router),
              ],
            ),
    );
  }
}

/// Cinta arriba a la derecha: qué módulo se está corriendo. Al tocarla abre
/// el menú con sus pantallas.
class _EtiquetaModulo extends ConsumerWidget {
  final Modulo modulo;
  final GoRouter router;
  const _EtiquetaModulo({required this.modulo, required this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conSesion = ref.watch(authStateProvider).valueOrNull != null;
    return Positioned(
      right: 8,
      bottom: 8,
      child: SafeArea(
        child: Material(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: conSesion ? () => router.go('/modulo') : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                conSesion ? '${modulo.etiqueta}  ·  menú' : modulo.etiqueta,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
