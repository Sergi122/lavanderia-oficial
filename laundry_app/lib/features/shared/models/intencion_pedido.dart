import 'package:cloud_firestore/cloud_firestore.dart';

/// armando → el cliente está llenando el pedido (casa en construcción);
/// confirmada → lo envió (casa terminada); cancelada → salió sin enviar.
enum EstadoIntencion { armando, confirmada, cancelada }

class IntencionPedido {
  final String clienteUid;
  final String clienteNombre;
  final String lavanderiaId;
  final double? lat;
  final double? lng;
  final EstadoIntencion estado;
  final String? pedidoId;
  final DateTime? actualizadoEn;

  const IntencionPedido({
    required this.clienteUid,
    required this.clienteNombre,
    required this.lavanderiaId,
    required this.estado,
    this.lat,
    this.lng,
    this.pedidoId,
    this.actualizadoEn,
  });

  factory IntencionPedido.fromMap(String id, Map<String, dynamic> m) {
    return IntencionPedido(
      clienteUid: id,
      clienteNombre: m['clienteNombre'] as String? ?? '',
      lavanderiaId: m['lavanderiaId'] as String? ?? '',
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      estado: EstadoIntencion.values.firstWhere(
        (e) => e.name == m['estado'],
        orElse: () => EstadoIntencion.armando,
      ),
      pedidoId: m['pedidoId'] as String?,
      actualizadoEn: (m['actualizadoEn'] is Timestamp)
          ? (m['actualizadoEn'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': clienteUid,
    'nombre': clienteNombre,
    'lat': lat,
    'lng': lng,
    'estado': estado.name,
    'pedidoId': pedidoId,
    'ts': actualizadoEn?.millisecondsSinceEpoch,
  };
}
