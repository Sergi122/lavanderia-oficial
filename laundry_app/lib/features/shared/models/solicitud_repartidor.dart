import 'package:cloud_firestore/cloud_firestore.dart';

import 'estado_solicitud.dart';

export 'estado_solicitud.dart';

class SolicitudRepartidor {
  final String uid;
  final String nombre;
  final String telefono;
  final String ci;
  final String placaMoto;
  final String carnetAnversoBase64;
  final String carnetReversoBase64;
  final String matriculaMotoBase64;
  final String licenciaConducirBase64;
  final String selfieFrenteBase64;
  final String selfieIzquierdaBase64;
  final String selfieDerechaBase64;
  final EstadoSolicitud estado;
  final String motivoRechazo;
  final DateTime? creadoEn;
  final double? verificacionAutomaticaDistancia;
  final bool? verificacionAutomaticaCoincide;
  final bool posibleDuplicado;
  final String motivoDuplicado;

  /// Prueba de vida del backend (selfies girando la cabeza). null = no se corrió.
  final bool? pruebaVidaOk;
  final String motivoPruebaVida;
  final bool discrepanciaDocumentos;
  final String motivoDiscrepancia;

  const SolicitudRepartidor({
    required this.uid,
    required this.nombre,
    required this.telefono,
    required this.ci,
    required this.placaMoto,
    required this.carnetAnversoBase64,
    required this.carnetReversoBase64,
    required this.matriculaMotoBase64,
    required this.licenciaConducirBase64,
    required this.selfieFrenteBase64,
    required this.selfieIzquierdaBase64,
    required this.selfieDerechaBase64,
    required this.estado,
    this.motivoRechazo = '',
    this.creadoEn,
    this.verificacionAutomaticaDistancia,
    this.verificacionAutomaticaCoincide,
    this.posibleDuplicado = false,
    this.motivoDuplicado = '',
    this.pruebaVidaOk,
    this.motivoPruebaVida = '',
    this.discrepanciaDocumentos = false,
    this.motivoDiscrepancia = '',
  });

  factory SolicitudRepartidor.fromMap(Map<String, dynamic> map) {
    return SolicitudRepartidor(
      uid: map['uid'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      telefono: map['telefono'] as String? ?? '',
      ci: map['ci'] as String? ?? '',
      placaMoto: map['placaMoto'] as String? ?? '',
      carnetAnversoBase64: map['carnetAnversoBase64'] as String? ?? '',
      carnetReversoBase64: map['carnetReversoBase64'] as String? ?? '',
      matriculaMotoBase64: map['matriculaMotoBase64'] as String? ?? '',
      licenciaConducirBase64: map['licenciaConducirBase64'] as String? ?? '',
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
      posibleDuplicado: map['posibleDuplicado'] as bool? ?? false,
      motivoDuplicado: map['motivoDuplicado'] as String? ?? '',
      pruebaVidaOk: map['pruebaVidaOk'] as bool?,
      motivoPruebaVida: map['motivoPruebaVida'] as String? ?? '',
      discrepanciaDocumentos: map['discrepanciaDocumentos'] as bool? ?? false,
      motivoDiscrepancia: map['motivoDiscrepancia'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': nombre,
      'telefono': telefono,
      'ci': ci,
      'placaMoto': placaMoto,
      'carnetAnversoBase64': carnetAnversoBase64,
      'carnetReversoBase64': carnetReversoBase64,
      'matriculaMotoBase64': matriculaMotoBase64,
      'licenciaConducirBase64': licenciaConducirBase64,
      'selfieFrenteBase64': selfieFrenteBase64,
      'selfieIzquierdaBase64': selfieIzquierdaBase64,
      'selfieDerechaBase64': selfieDerechaBase64,
      'estado': estado.name,
      'motivoRechazo': motivoRechazo,
      'creadoEn': FieldValue.serverTimestamp(),
    };
  }
}
