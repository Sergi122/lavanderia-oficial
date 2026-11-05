# Módulo Gestión de cuentas y acceso — Luis Dorado

Sprint 1 de la división de octubre, con el **código nuevo por módulos** (noviembre).

Incluye: crear cuenta, verificar el correo con código, iniciar y cerrar sesión,
redirección según el rol, recuperar contraseña, cuenta suspendida, completar y
editar perfil, y la página pública de bienvenida (desde donde se entra al login).

| Qué | Dónde |
|---|---|
| Pantallas del módulo | `laundry_app/lib/modulos/cuentas/pantallas/` |
| Código por correo | `laundry_app/lib/modulos/cuentas/datos/codigo_correo_api.dart` |
| Rutas del módulo | `laundry_app/lib/modulos/cuentas/modulo_cuentas.dart` |
| Sesión (Firebase Auth) | `laundry_app/lib/core/sesion/auth_repository.dart` |
| Usuario y roles | `laundry_app/lib/core/contrato/modelos/app_user.dart` |
| Redirección por rol | `laundry_app/lib/core/router/app_router.dart` |
| Arranque por módulos | `laundry_app/lib/arranque.dart`, `laundry_app/lib/core/arranque/` |
| Página pública | `laundry_app/lib/modulos/localizacion/pantallas/landing_screen*.dart`, `landing/public/index.html` |
| Arranque solo de este módulo | `laundry_app/lib/main_octubre_cuentas.dart` |

Correr solo este módulo (desde la app completa):

```
flutter run -d chrome --web-port 8080 -t lib/main_octubre_cuentas.dart
```
