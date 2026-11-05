# Módulo Gestión de pedidos del cliente — Sergio Poma

Sprint 2 de la división de octubre, con el **código nuevo por módulos** (noviembre).
En noviembre este trabajo quedó en dos módulos, los dos de Sergio:
S2 Localización de lavanderías y S6 Gestión de pedidos del cliente.

Incluye: mapa y detalle de lavanderías, marcar la casa y el punto de recojo,
crear un pedido, seguirlo, ver el historial, el comprobante y los avisos del pedido.

| Qué | Dónde |
|---|---|
| Mapa, inicio del cliente, marcar casa | `laundry_app/lib/modulos/localizacion/pantallas/` |
| Crear, seguir y ver pedidos | `laundry_app/lib/modulos/pedidos_cliente/pantallas/` |
| Rutas de cada parte | `modulo_localizacion.dart`, `modulo_pedidos_cliente.dart` |
| Datos (Firebase) | `laundry_app/lib/core/contrato/datos/` (pedido, lavandería, precio) |
| Modelo del pedido | `laundry_app/lib/core/contrato/modelos/pedido.dart` |
| GPS y ubicación | `laundry_app/lib/core/ubicacion/ubicacion.dart` |
| Barra y botones del cliente | `laundry_app/lib/core/marcos/`, `laundry_app/lib/core/widgets/nube_acciones.dart` |
| Arranque solo de este módulo | `laundry_app/lib/main_octubre_pedidos.dart` |

Correr solo este módulo (desde la app completa):

```
flutter run -d chrome --web-port 8080 -t lib/main_octubre_pedidos.dart
```
