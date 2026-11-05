# Módulo Administración de finanzas — Emanuel Velasco

Sprint 5 de la división de octubre, con el **código nuevo por módulos** (noviembre).

Incluye: ingresos, egresos, planilla, balance, informe PDF, comprobante digital
del pedido y ganancias del repartidor.

| Qué | Dónde |
|---|---|
| Pantallas de finanzas | `laundry_app/lib/modulos/finanzas/pantallas/`, `widgets/` |
| Datos de finanzas (Firebase) | `laundry_app/lib/modulos/finanzas/datos/finanzas_repository.dart` |
| Rutas del módulo | `laundry_app/lib/modulos/finanzas/modulo_finanzas.dart` |
| Comprobante digital | `laundry_app/lib/modulos/pedidos_cliente/pantallas/comprobante_screen.dart` |
| Ganancias del repartidor | `laundry_app/lib/modulos/reparto/pantallas/repartidor_home_screen.dart`, `reparto/datos/repartidor_repository.dart` |
| Arranque solo de este módulo | `laundry_app/lib/main_octubre_finanzas.dart` |

Correr solo este módulo (desde la app completa):

```
flutter run -d chrome --web-port 8080 -t lib/main_octubre_finanzas.dart
```
