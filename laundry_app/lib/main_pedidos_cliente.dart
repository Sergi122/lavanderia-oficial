import 'arranque.dart';
import 'modulos/pedidos_cliente/modulo_pedidos_cliente.dart';

/// Solo este módulo (más el inicio de sesión de S1).
/// Correr: flutter run -d chrome -t lib/main_pedidos_cliente.dart
Future<void> main() =>
    arrancarApp([moduloPedidosCliente], presentado: moduloPedidosCliente);
