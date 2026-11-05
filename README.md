# Módulo Gestión de lavanderías — Paulo Ferrufino

Sprint 3 de la división de octubre, con el **código nuevo por módulos** (noviembre).

Incluye: solicitar apertura de la lavandería, configurar datos, horario, precios y
descuentos, panel del negocio en vivo y la lavandería en 3D.

| Qué | Dónde |
|---|---|
| Pantallas del módulo | `laundry_app/lib/modulos/lavanderia/pantallas/` |
| Rutas del módulo | `laundry_app/lib/modulos/lavanderia/modulo_lavanderia.dart` |
| Abrir mi lavandería | `laundry_app/lib/modulos/afiliacion/pantallas/abrir_lavanderia_screen.dart` |
| Datos (Firebase) | `laundry_app/lib/core/contrato/datos/` (apertura y lavandería) |
| Modelos | `laundry_app/lib/core/contrato/modelos/` (lavandería, solicitud, horario, tema del panel) |
| Lavandería en 3D | `laundry_app/lib/core/escena_3d/` |
| Arranque solo de este módulo | `laundry_app/lib/main_octubre_lavanderia.dart` |

Correr solo este módulo (desde la app completa):

```
flutter run -d chrome -t lib/main_octubre_lavanderia.dart
```
