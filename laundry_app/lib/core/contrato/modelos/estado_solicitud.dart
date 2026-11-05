// `identidadConfirmada` solo aplica a solicitudes de lavandería: el
// verificador confirma primero la identidad de la persona, y ese estado
// intermedio queda pendiente de que el superadmin revise el local en sí
// (ubicación, NIT, fotos, posibles duplicados) antes de la aprobación final.
enum EstadoSolicitud { pendiente, identidadConfirmada, aprobada, rechazada }

EstadoSolicitud estadoSolicitudFromString(String value) {
  return EstadoSolicitud.values.firstWhere(
    (e) => e.name == value,
    orElse: () => EstadoSolicitud.pendiente,
  );
}

extension EstadoSolicitudLabel on EstadoSolicitud {
  String get label {
    switch (this) {
      case EstadoSolicitud.pendiente:
        return 'En revisión';
      case EstadoSolicitud.identidadConfirmada:
        return 'Identidad confirmada — revisando el local';
      case EstadoSolicitud.aprobada:
        return 'Aprobada';
      case EstadoSolicitud.rechazada:
        return 'Rechazada';
    }
  }
}
