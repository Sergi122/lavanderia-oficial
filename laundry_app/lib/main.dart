import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/background_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/codigo_correo_api.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await configurarServicioSegundoPlano();
  // Despierta el servidor de códigos/verificación (Render gratis se duerme).
  unawaited(CodigoCorreoApi.despertar());
  runApp(const ProviderScope(child: LaundryApp()));
}

class LaundryApp extends ConsumerWidget {
  const LaundryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

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
      title: 'Lavandería App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
