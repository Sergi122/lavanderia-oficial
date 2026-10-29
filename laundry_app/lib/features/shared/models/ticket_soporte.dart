import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoTicket { abierto, resuelto }

EstadoTicket estadoTicketFromString(String value) {
  return EstadoTicket.values.firstWhere(
    (e) => e.name == value,
    orElse: () => EstadoTicket.abierto,
  );
}

class TicketSoporte {
  final String id;
  final String autorUid;
  final String autorNombre;
  final String lavanderiaId;
  final String lavanderiaNombre;
  final String asunto;
  final String mensaje;
  final EstadoTicket estado;
  final DateTime? creadoEn;

  /// Quién lo abrió ('admin', 'cliente', 'empleado', 'repartidor').
  final String rolAutor;
  final String categoria;
  final String? pedidoId;

  /// Lo que contestó el superadmin al resolverlo (vacío si aún no).
  final String respuesta;

  const TicketSoporte({
    required this.id,
    required this.autorUid,
    required this.autorNombre,
    required this.lavanderiaId,
    required this.lavanderiaNombre,
    required this.asunto,
    required this.mensaje,
    required this.estado,
    this.creadoEn,
    this.rolAutor = 'admin',
    this.categoria = '',
    this.pedidoId,
    this.respuesta = '',
  });

  factory TicketSoporte.fromMap(String id, Map<String, dynamic> map) {
    return TicketSoporte(
      id: id,
      autorUid: map['autorUid'] as String? ?? '',
      autorNombre: map['autorNombre'] as String? ?? '',
      lavanderiaId: map['lavanderiaId'] as String? ?? '',
      lavanderiaNombre: map['lavanderiaNombre'] as String? ?? '',
      asunto: map['asunto'] as String? ?? '',
      mensaje: map['mensaje'] as String? ?? '',
      estado: estadoTicketFromString(map['estado'] as String? ?? 'abierto'),
      creadoEn: (map['creadoEn'] as Timestamp?)?.toDate(),
      rolAutor: map['rolAutor'] as String? ?? 'admin',
      categoria: map['categoria'] as String? ?? '',
      pedidoId: map['pedidoId'] as String?,
      respuesta: map['respuesta'] as String? ?? '',
    );
  }
}
