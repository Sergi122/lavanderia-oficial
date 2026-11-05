import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../arranque/menu_modulo_screen.dart';
import '../arranque/modulo.dart';
import '../contrato/modelos/app_user.dart';
import '../legal/legal_screens.dart';
import '../legal/textos_legales.dart';
import '../sesion/auth_repository.dart';

/// Rutas del núcleo + las de cada módulo activo. Este archivo NO importa
/// ningún módulo: cada módulo trae sus rutas (`lib/modulos/<m>/modulo_<m>.dart`)
/// y el main_*.dart decide cuáles entran.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final appUserState = ref.watch(currentAppUserProvider);
  final modulos = ref.watch(modulosActivosProvider);
  final rutasModulos = [for (final m in modulos) ...m.rutas];
  final existentes = {
    for (final r in rutasModulos)
      if (r is GoRoute) r.path,
  };
  bool existe(String ruta) => existentes.contains(ruta);

  return GoRouter(
    initialLocation: '/splash',
    errorBuilder: (context, state) =>
        FueraDelModuloScreen(ruta: state.uri.path),
    routes: [
      ...rutasModulos,
      GoRoute(path: '/modulo', builder: (_, _) => const MenuModuloScreen()),
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
        if (!existe('/bienvenida')) return loggingIn ? null : '/login';
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
      // Inicio del rol; si su módulo no está en esta versión, el menú del
      // módulo (/modulo) con las pantallas que sí están.
      final inicioRol = '/${prefijoRol(role)}';
      final destino = existe(inicioRol) ? inicioRol : '/modulo';

      // Cliente recién registrado: primero completa su perfil (nombres,
      // apellidos y punto de recojo). No lleva verificación de identidad.
      const rutaPerfil = '/cliente/completar-perfil';
      if (appUser != null &&
          role == UserRole.cliente &&
          !appUser.perfilCompleto &&
          existe(rutaPerfil)) {
        return state.matchedLocation == rutaPerfil ? null : rutaPerfil;
      }

      if (loggingIn ||
          splashing ||
          bienvenida ||
          suspendida ||
          state.matchedLocation == rutaTerminos) {
        return destino;
      }

      // El menú del módulo lo ve cualquier cuenta con sesión.
      if (state.matchedLocation == '/modulo') return null;

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
