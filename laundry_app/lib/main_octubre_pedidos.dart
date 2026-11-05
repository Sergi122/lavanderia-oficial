import 'arranque.dart';
import 'core/arranque/modulo.dart';
import 'modulos/localizacion/modulo_localizacion.dart';
import 'modulos/pedidos_cliente/modulo_pedidos_cliente.dart';

/// Módulo de OCTUBRE de Sergio (Sprint 2, «Gestión de pedidos del cliente»),
/// armado con el código nuevo: mapa y detalle de lavanderías, marcar casa y
/// punto de recojo (hoy S2 Localización) + crear, seguir y ver el historial
/// de pedidos (hoy S6 Pedidos del cliente).
/// Correr: flutter run -d chrome -t lib/main_octubre_pedidos.dart
final _octubre = Modulo(
  numero: 2,
  id: 'pedidos_octubre',
  nombre: 'Gestión de pedidos del cliente (octubre)',
  responsable: 'Sergio Poma',
  rutas: [...moduloLocalizacion.rutas, ...moduloPedidosCliente.rutas],
  entradas: [...moduloLocalizacion.entradas, ...moduloPedidosCliente.entradas],
);

Future<void> main() => arrancarApp([_octubre], presentado: _octubre);
