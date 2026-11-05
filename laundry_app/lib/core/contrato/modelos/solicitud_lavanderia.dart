import 'package:cloud_firestore/cloud_firestore.dart';

import 'estado_solicitud.dart';

export 'estado_solicitud.dart';

class SolicitudLavanderia {
  final String propietarioUid;
  final String nombrePropietario;
  final String ciPropietario;
  final String telefonoPropietario;
  final String nombre;
  final String nit;
  final String direccion;
  final double lat;
  final double lng;
  final List<String> servicios;
  final Map<String, double> precios;
  final bool mostrarPrecios;
  final double? precioDocena;
  final double? precioKg;
  final double costoEnvio;
  final bool entregaDomicilio;
  final List<String> fotosBase64;
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
  final bool posibleDuplicado;
  final String motivoDuplicado;

  /// Prueba de vida del backend (selfies girando la cabeza). null = no se corrió.
  final bool? pruebaVidaOk;
  final String motivoPruebaVida;

  const SolicitudLavanderia({
    required this.propietarioUid,
    this.nombrePropietario = '',
    this.ciPropietario = '',
    this.telefonoPropietario = '',
    required this.nombre,
    required this.nit,
    required this.direccion,
    required this.lat,
    required this.lng,
    required this.servicios,
    required this.precios,
    required this.mostrarPrecios,
    this.precioDocena,
    this.precioKg,
    required this.costoEnvio,
    required this.entregaDomicilio,
    required this.fotosBase64,
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
    this.posibleDuplicado = false,
    this.motivoDuplicado = '',
    this.pruebaVidaOk,
    this.motivoPruebaVida = '',
  });

  factory SolicitudLavanderia.fromMap(Map<String, dynamic> map) {
    return SolicitudLavanderia(
      propietarioUid: map['propietarioUid'] as String? ?? '',
      nombrePropietario: map['nombrePropietario'] as String? ?? '',
      ciPropietario: map['ciPropietario'] as String? ?? '',
      telefonoPropietario: map['telefonoPropietario'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      nit: map['nit'] as String? ?? '',
      direccion: map['direccion'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      servicios: (map['servicios'] as List?)?.cast<String>() ?? const [],
      precios:
          (map['precios'] as Map?)?.map(
            (key, value) => MapEntry(key as String, (value as num).toDouble()),
          ) ??
          const {},
      mostrarPrecios: map['mostrarPrecios'] as bool? ?? false,
      precioDocena: (map['precioDocena'] as num?)?.toDouble(),
      precioKg: (map['precioKg'] as num?)?.toDouble(),
      costoEnvio: (map['costoEnvio'] as num?)?.toDouble() ?? 0,
      entregaDomicilio: map['entregaDomicilio'] as bool? ?? false,
      fotosBase64: (map['fotosBase64'] as List?)?.cast<String>() ?? const [],
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
      posibleDuplicado: map['posibleDuplicado'] as bool? ?? false,
      motivoDuplicado: map['motivoDuplicado'] as String? ?? '',
      pruebaVidaOk: map['pruebaVidaOk'] as bool?,
      motivoPruebaVida: map['motivoPruebaVida'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'propietarioUid': propietarioUid,
      'nombrePropietario': nombrePropietario,
      'ciPropietario': ciPropietario,
      'telefonoPropietario': telefonoPropietario,
      'nombre': nombre,
      'nit': nit,
      'direccion': direccion,
      'lat': lat,
      'lng': lng,
      'servicios': servicios,
      'precios': precios,
      'mostrarPrecios': mostrarPrecios,
      if (precioDocena != null) 'precioDocena': precioDocena,
      if (precioKg != null) 'precioKg': precioKg,
      'costoEnvio': costoEnvio,
      'entregaDomicilio': entregaDomicilio,
      'fotosBase64': fotosBase64,
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

  /// Solo los campos públicos que pasan a la colección `lavanderias` al aprobar.
  Map<String, dynamic> toLavanderiaMap() {
    return {
      'nombre': nombre,
      'direccion': direccion,
      'lat': lat,
      'lng': lng,
      'servicios': servicios,
      'precios': mostrarPrecios ? precios : <String, double>{},
      if (mostrarPrecios && precioDocena != null) 'precioDocena': precioDocena,
      if (mostrarPrecios && precioKg != null) 'precioKg': precioKg,
      'costoEnvio': costoEnvio,
      'entregaDomicilio': entregaDomicilio,
      'propietarioUid': propietarioUid,
      'fotosBase64': fotosBase64,
    };
  }
}
