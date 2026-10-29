import 'package:cloud_firestore/cloud_firestore.dart';

class Convocatoria {
  final String id;
  final String lavanderiaId;
  final String lavanderiaNombre;
  final String puesto;
  final double salario;
  final String horario;
  final String descripcion;
  final bool abierta;
  final DateTime? creadoEn;

  const Convocatoria({
    required this.id,
    required this.lavanderiaId,
    required this.lavanderiaNombre,
    required this.puesto,
    required this.salario,
    required this.horario,
    required this.descripcion,
    required this.abierta,
    this.creadoEn,
  });

  factory Convocatoria.fromMap(String id, Map<String, dynamic> map) {
    return Convocatoria(
      id: id,
      lavanderiaId: map['lavanderiaId'] as String? ?? '',
      lavanderiaNombre: map['lavanderiaNombre'] as String? ?? '',
      puesto: map['puesto'] as String? ?? '',
      salario: (map['salario'] as num?)?.toDouble() ?? 0,
      horario: map['horario'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      abierta: map['abierta'] as bool? ?? true,
      creadoEn: (map['creadoEn'] as Timestamp?)?.toDate(),
    );
  }
}

class PostulanteConvocatoria {
  final String uid;
  final String nombre;
  final String telefono;
  final String mensaje;
  final DateTime? fecha;

  const PostulanteConvocatoria({
    required this.uid,
    required this.nombre,
    required this.telefono,
    required this.mensaje,
    this.fecha,
  });

  factory PostulanteConvocatoria.fromMap(String uid, Map<String, dynamic> map) {
    return PostulanteConvocatoria(
      uid: uid,
      nombre: map['nombre'] as String? ?? '',
      telefono: map['telefono'] as String? ?? '',
      mensaje: map['mensaje'] as String? ?? '',
      fecha: (map['fecha'] as Timestamp?)?.toDate(),
    );
  }
}
