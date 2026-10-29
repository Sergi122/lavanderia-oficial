import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/legal/legal_screens.dart';
import '../../features/legal/textos_legales.dart';
import '../../features/admin/presentation/admin_empleados_screen.dart';
import '../../features/admin/presentation/admin_home_screen.dart';
import '../../features/admin/presentation/editar_lavanderia_screen.dart';
import '../../features/admin/presentation/finanzas_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/cuenta_suspendida_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/verificar_correo_screen.dart';
import '../../features/client/presentation/abrir_lavanderia_screen.dart';
import '../../features/client/presentation/client_home_screen.dart';
import '../../features/client/presentation/completar_perfil_screen.dart';
import '../../features/client/presentation/mapa_lavanderias_screen.dart';
import '../../features/client/presentation/nuevo_pedido_screen.dart';
import '../../features/client/presentation/realizar_pedido_screen.dart';
import '../../features/client/presentation/postular_empleado_screen.dart';
import '../../features/client/presentation/trabajar_screen.dart';
import '../verificacion/paso_identidad.dart';
import '../widgets/proximamente.dart';
import '../../features/employee/presentation/convocatorias_empleado_screen.dart';
import '../../features/shared/models/app_user.dart';
import '../../features/shared/models/lavanderia.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final appUserState = ref.watch(currentAppUserProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/bienvenida',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/cuenta-suspendida',
        builder: (context, state) => const CuentaSuspendidaScreen(),
      ),
      GoRoute(
        path: '/verificar-correo',
        builder: (context, state) => const VerificarCorreoScreen(),
      ),
      GoRoute(
        path: '/cliente/completar-perfil',
        builder: (context, state) => const CompletarPerfilScreen(),
      ),
      GoRoute(
        path: '/cliente',
        builder: (context, state) => const ClientHomeScreen(),
      ),
      GoRoute(
        path: '/cliente/mapa',
        builder: (context, state) => const MapaLavanderiasScreen(),
      ),
      GoRoute(
        path: '/cliente/nuevo-pedido',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is PedidoInicial) {
            return NuevoPedidoScreen(
              lavanderia: extra.lavanderia,
              puntoInicial: extra.punto,
              direccionInicial: extra.direccion,
            );
          }
          return NuevoPedidoScreen(lavanderia: extra as Lavanderia);
        },
      ),
      GoRoute(
        path: '/cliente/realizar-pedido',
        builder: (context, state) => const RealizarPedidoScreen(),
      ),
      GoRoute(
        path: '/cliente/asistencia',
        builder: (context, state) => const ProximamenteScreen(
          titulo: 'Asistencia',
          sprint: 'el Sprint de Soporte',
        ),
      ),
      GoRoute(
        path: '/cliente/perfil',
        builder: (context, state) => const ProximamenteScreen(
          titulo: 'Mi perfil',
          sprint: 'la segunda parte',
        ),
      ),
      GoRoute(
        path: '/cliente/trabajar',
        builder: (context, state) => const TrabajarScreen(),
      ),
      GoRoute(
        path: '/cliente/abrir-lavanderia',
        builder: (context, state) => AbrirLavanderiaScreen(
          identidadInicial: state.extra as VerificacionIdentidad?,
        ),
      ),
      GoRoute(
        path: '/cliente/postular-repartidor',
        builder: (context, state) => const ProximamenteScreen(
          titulo: 'Postular como repartidor',
          sprint: 'el Sprint de Reparto',
        ),
      ),
      GoRoute(
        path: '/cliente/postular-empleado',
        builder: (context, state) => PostularEmpleadoScreen(
          identidadInicial: state.extra as VerificacionIdentidad?,
        ),
      ),
      GoRoute(
        path: '/admin/editar',
        builder: (context, state) => const EditarLavanderiaScreen(),
      ),
      GoRoute(
        path: '/admin/finanzas',
        builder: (context, state) => const FinanzasScreen(),
      ),
      GoRoute(
        path: '/admin/empleados',
        builder: (context, state) => const AdminEmpleadosScreen(),
      ),
      GoRoute(
        path: '/empleado',
        builder: (context, state) => const ProximamenteScreen(
          titulo: 'Panel del empleado',
          sprint: 'la parte 2 de Gestión de pedidos',
        ),
      ),
      GoRoute(
        path: '/empleado/perfil',
        builder: (context, state) => const ProximamenteScreen(
          titulo: 'Mi perfil',
          sprint: 'la segunda parte',
        ),
      ),
      GoRoute(
        path: '/empleado/convocatorias',
        builder: (context, state) => const ConvocatoriasEmpleadoScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: '/verificador',
        builder: (context, state) => const ProximamenteScreen(
          titulo: 'Panel del verificador',
          sprint: 'el módulo de Verificación',
        ),
      ),
      GoRoute(
        path: '/repartidor',
        builder: (context, state) => const ProximamenteScreen(
          titulo: 'Panel del repartidor',
          sprint: 'el Sprint de Reparto',
        ),
      ),
      GoRoute(
        path: '/repartidor/perfil',
        builder: (context, state) => const ProximamenteScreen(
          titulo: 'Mi perfil',
          sprint: 'el Sprint de Reparto',
        ),
      ),
      GoRoute(
        path: '/superadmin',
        builder: (context, state) => const ProximamenteScreen(
          titulo: 'Administración de la plataforma',
          sprint: 'el módulo de Administración de plataforma',
        ),
      ),
      GoRoute(
        path: '/legal/:tipo',
        builder: (context, state) => DocumentoLegalScreen(
          tipo: state.pathParameters['tipo'] == 'terminos'
              ? 'terminos'
              : 'privacidad',
        ),
      ),
      GoRoute(
        path: '/aceptar-terminos',
        builder: (context, state) => const AceptarTerminosScreen(),
      ),
    ],
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final loggingIn = state.matchedLocation == '/login';
      final splashing = state.matchedLocation == '/splash';
      final bienvenida = state.matchedLocation == '/bienvenida';

      if (authState.isLoading) return splashing ? null : '/splash';
      // La política y los términos se leen con o sin sesión (desde el registro).
      if (state.matchedLocation.startsWith('/legal/')) return null;
      // Web: la presentación pública vive en la landing estática (raíz del
      // sitio); la app solo muestra el login a quien no ha iniciado sesión.
      if (user == null) {
        if (kIsWeb) return loggingIn ? null : '/login';
        return (loggingIn || bienvenida) ? null : '/bienvenida';
      }

      // Correo/contraseña sin verificar (Google ya llega verificado): no lo
      // dejamos pasar a ninguna pantalla hasta que confirme el enlace.
      final verificandoCorreo = state.matchedLocation == '/verificar-correo';
      if (!user.emailVerified) {
        return verificandoCorreo ? null : '/verificar-correo';
      }

      // Sesión activa: esperamos el perfil (rol) antes de decidir destino.
      if (appUserState.isLoading && !appUserState.hasValue) {
        return splashing ? null : '/splash';
      }

      final appUser = appUserState.valueOrNull;
      final suspendida = state.matchedLocation == '/cuenta-suspendida';
      if (appUser != null && !appUser.activo) {
        return suspendida ? null : '/cuenta-suspendida';
      }

      // Política de privacidad y términos: obligatorio aceptar la versión
      // vigente (cuentas de Google, anteriores al piloto o tras un cambio).
      const rutaTerminos = '/aceptar-terminos';
      if (appUser != null && appUser.terminosVersion != kVersionTerminos) {
        return state.matchedLocation == rutaTerminos ? null : rutaTerminos;
      }

      final role = appUser?.role ?? UserRole.cliente;
      final destino = switch (role) {
        UserRole.empleado => '/empleado',
        UserRole.admin => '/admin',
        UserRole.verificador => '/verificador',
        UserRole.repartidor => '/repartidor',
        UserRole.superadmin => '/superadmin',
        UserRole.cliente => '/cliente',
      };

      // Cliente recién registrado: primero completa su perfil (nombres,
      // apellidos y punto de recojo). No lleva verificación de identidad.
      const rutaPerfil = '/cliente/completar-perfil';
      if (appUser != null &&
          role == UserRole.cliente &&
          !appUser.perfilCompleto) {
        return state.matchedLocation == rutaPerfil ? null : rutaPerfil;
      }

      if (loggingIn ||
          splashing ||
          bienvenida ||
          suspendida ||
          state.matchedLocation == rutaTerminos) {
        return destino;
      }

      // Cada rol solo puede navegar dentro de sus propias pantallas — sin
      // esto, cualquier usuario logueado podía escribir /admin, /superadmin,
      // etc. en la URL y ver esas pantallas aunque no le correspondan.
      final rutaPermitida = switch (role) {
        UserRole.cliente => state.matchedLocation.startsWith('/cliente'),
        // El empleado también puede usar el lado cliente (pedir su propia
        // ropa) — es la misma cuenta, no pierde ese acceso por trabajar ahí.
        UserRole.empleado =>
          state.matchedLocation.startsWith('/empleado') ||
              state.matchedLocation.startsWith('/cliente'),
        UserRole.admin => state.matchedLocation.startsWith('/admin'),
        UserRole.verificador => state.matchedLocation.startsWith(
          '/verificador',
        ),
        // El repartidor también puede pedir su propia ropa (misma cuenta).
        UserRole.repartidor =>
          state.matchedLocation.startsWith('/repartidor') ||
              state.matchedLocation.startsWith('/cliente'),
        UserRole.superadmin => state.matchedLocation.startsWith('/superadmin'),
      };
      if (!rutaPermitida) return destino;

      return null;
    },
    refreshListenable: GoRouterRefreshStream(ref),
  );
});

/// Puentea los providers de riverpod con el Listenable que go_router
/// necesita para refrescar el redirect cuando cambia la sesión o el rol.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentAppUserProvider, (_, _) => notifyListeners());
  }
}
