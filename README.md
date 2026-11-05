# Módulo Gestión de personal y empleo — Milen Aliaga

Sprint 4 de la división de octubre, con el **código nuevo por módulos** (noviembre).

Incluye: convocatorias de empleo, postular como empleado, perfil laboral,
contratar, gestionar el equipo de la lavandería y la actividad del empleado.

| Qué | Dónde |
|---|---|
| Pantallas del módulo | `laundry_app/lib/modulos/personal/pantallas/` |
| Rutas del módulo | `laundry_app/lib/modulos/personal/modulo_personal.dart` |
| Datos (Firebase) | `laundry_app/lib/core/contrato/datos/` (empleo, empleados, actividad) |
| Modelos | `laundry_app/lib/core/contrato/modelos/` (convocatoria, solicitud, estado) |
| Arranque solo de este módulo | `laundry_app/lib/main_personal.dart` |

Correr solo este módulo (desde la app completa):

```
flutter run -d chrome --web-port 8080 -t lib/main_personal.dart
```
