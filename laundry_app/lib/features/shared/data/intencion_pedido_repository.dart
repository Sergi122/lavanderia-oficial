import 'package:flutter_riverpod/flutter_riverpod.dart';

/// El aviso en vivo a la lavandería de que un cliente está armando un pedido
/// llega con la parte 2 de Gestión de pedidos; mientras tanto no hace nada.
final intencionPedidoRepositoryProvider = Provider<IntencionPedidoRepository>(
  (ref) => IntencionPedidoRepository(),
);

class IntencionPedidoRepository {
  Future<void> empezar({
    required String clienteUid,
    required String clienteNombre,
    required String lavanderiaId,
    double? lat,
    double? lng,
  }) async {}

  Future<void> moverPunto(String clienteUid, double lat, double lng) async {}

  Future<void> confirmar(String clienteUid, String pedidoId) async {}

  Future<void> cancelar(String clienteUid) async {}
}
