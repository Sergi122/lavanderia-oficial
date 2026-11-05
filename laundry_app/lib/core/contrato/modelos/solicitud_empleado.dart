import 'package:cloud_firestore/cloud_firestore.dart';

import 'estado_solicitud.dart';

export 'estado_solicitud.dart';

class SolicitudEmpleado {
  final String uid;
  final String nombre;
  final String direccion;
  final int edad;
  final String ci;
  final String telefono;
  final String lavanderiaId;
  final String cvNombre;
  final String cvBase64;
  final String carnetAnversoBase64;
  final String carnetReversoBase64;
  final String selfieFrenteBase64;
  final String selfieIzquierdaBase64;
  final String selfieDerechaBase64;
  final EstadoSolicitud estado;
  final String motivoRechazo;
  final DateTime? creadoEn;
  final double? verificacionAutomaticaDistancia;
  final bool? verificacionAutomaticaCoincide;

  const SolicitudEmpleado({
    required this.uid,
    required this.nombre,
    required this.direccion,
    required this.edad,
    required this.ci,
    required this.telefono,
    required this.lavanderiaId,
    required this.cvNombre,
    required this.cvBase64,
    required this.carnetAnversoBase64,
    required this.carnetReversoBase64,
    required this.selfieFrenteBase64,
    required this.selfieIzquierdaBase64,
    required this.selfieDerechaBase64,
    required this.estado,
    this.motivoRechazo = '',
    this.creadoEn,
    this.verificacionAutomaticaDistancia,
    this.verificacionAutomaticaCoincide,
  });

  factory SolicitudEmpleado.fromMap(Map<String, dynamic> map) {
    return SolicitudEmpleado(
      uid: map['uid'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      direccion: map['direccion'] as String? ?? '',
      edad: (map['edad'] as num?)?.toInt() ?? 0,
      ci: map['ci'] as String? ?? '',
      telefono: map['telefono'] as String? ?? '',
      lavanderiaId: map['lavanderiaId'] as String? ?? '',
      cvNombre: map['cvNombre'] as String? ?? '',
      cvBase64: map['cvBase64'] as String? ?? '',
      carnetAnversoBase64: map['carnetAnversoBase64'] as String? ?? '',
      carnetReversoBase64: map['carnetReversoBase64'] as String? ?? '',
      selfieFrenteBase64: map['selfieFrenteBase64'] as String? ?? '',
      selfieIzquierdaBase64: map['selfieIzquierdaBase64'] as String? ?? '',
      selfieDerechaBase64: map['selfieDerechaBase64'] as String? ?? '',
      estado: estadoSolicitudFromString(
        map['estado'] as String? ?? 'pendiente',
      ),
      motivoRechazo: map['motivoRechazo'] as String? ?? '',
      creadoEn: (map['creadoEn'] as Timestamp?)?.toDate(),
      verificacionAutomaticaDistancia:
          (map['verificacionAutomaticaDistancia'] as num?)?.toDouble(),
      verificacionAutomaticaCoincide:
          map['verificacionAutomaticaCoincide'] as bool?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': nombre,
      'direccion': direccion,
      'edad': edad,
      'ci': ci,
      'telefono': telefono,
      'lavanderiaId': lavanderiaId,
      'cvNombre': cvNombre,
      'cvBase64': cvBase64,
      'carnetAnversoBase64': carnetAnversoBase64,
      'carnetReversoBase64': carnetReversoBase64,
      'selfieFrenteBase64': selfieFrenteBase64,
      'selfieIzquierdaBase64': selfieIzquierdaBase64,
      'selfieDerechaBase64': selfieDerechaBase64,
      'estado': estado.name,
      'motivoRechazo': motivoRechazo,
      'creadoEn': FieldValue.serverTimestamp(),
    };
  }
}
