import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoPedido { recibido, enProceso, listo, entregado }

EstadoPedido estadoPedidoFromString(String value) {
  return EstadoPedido.values.firstWhere(
    (e) => e.name == value,
    orElse: () => EstadoPedido.recibido,
  );
}

extension EstadoPedidoLabel on EstadoPedido {
  String get label {
    switch (this) {
      case EstadoPedido.recibido:
        return 'Recibido';
      case EstadoPedido.enProceso:
        return 'En proceso';
      case EstadoPedido.listo:
        return 'Listo para recoger';
      case EstadoPedido.entregado:
        return 'Entregado';
    }
  }
}

enum ModoCobroRegular { pieza, docena, kilo }

ModoCobroRegular modoCobroRegularFromString(String value) {
  return ModoCobroRegular.values.firstWhere(
    (m) => m.name == value,
    orElse: () => ModoCobroRegular.pieza,
  );
}

enum TipoEntrega { clienteLleva, recojoDomicilio }

TipoEntrega tipoEntregaFromString(String value) {
  return TipoEntrega.values.firstWhere(
    (e) => e.name == value,
    orElse: () => TipoEntrega.clienteLleva,
  );
}

extension TipoEntregaLabel on TipoEntrega {
  String get label {
    switch (this) {
      case TipoEntrega.clienteLleva:
        return 'Yo llevo mis prendas';
      case TipoEntrega.recojoDomicilio:
        return 'Recojo a domicilio';
    }
  }
}

/// Pasos del repartidor en un pedido a domicilio, en orden.
enum EtapaReparto { aceptado, recogido, enLavanderia, devolviendo, completada }

EtapaReparto etapaRepartoFromString(String? value) {
  return EtapaReparto.values.firstWhere(
    (e) => e.name == value,
    orElse: () => EtapaReparto.aceptado,
  );
}

extension EtapaRepartoInfo on EtapaReparto {
  String get label {
    switch (this) {
      case EtapaReparto.aceptado:
        return 'Repartidor en camino a recoger tu ropa';
      case EtapaReparto.recogido:
        return 'Ropa recogida, va hacia la lavandería';
      case EtapaReparto.enLavanderia:
        return 'Tu ropa está en la lavandería';
      case EtapaReparto.devolviendo:
        return 'Tu ropa limpia va en camino a tu casa';
      case EtapaReparto.completada:
        return 'Entrega completada';
    }
  }

  EtapaReparto? get siguiente {
    final i = EtapaReparto.values.indexOf(this);
    return i + 1 < EtapaReparto.values.length
        ? EtapaReparto.values[i + 1]
        : null;
  }
}

class Pedido {
  final String id;
  final String clienteId;
  final String lavanderiaId;
  final String lavanderiaNombre;
  final Map<String, int> prendas;
  final String notas;
  final EstadoPedido estado;
  final DateTime? creadoEn;
  final TipoEntrega tipoEntrega;
  final String direccionRecojo;
  final double? recojoLat;
  final double? recojoLng;
  final double costoPrendas;
  final double costoEnvio;
  final ModoCobroRegular modoRopaRegular;
  final double cantidadRopaRegular;
  final String? repartidorUid;
  final bool entregaCompletada;
  final int? calificacionLavanderia;
  final int? calificacionRepartidor;
  final String comentarioCalificacion;
  final EtapaReparto etapaReparto;
  final String repartidorNombre;
  final String repartidorTelefono;
  final double? repartidorLat;
  final double? repartidorLng;
  final DateTime? repartidorActualizadoEn;
  final bool tieneComprobante;

  /// Nombre del cliente (copiado al crear, para mostrarlo sin leer su perfil).
  final String clienteNombre;

  /// Cuándo el empleado marcó "Recibí la ropa" (cliente que la trae él mismo).
  final DateTime? ropaRecibidaEn;

  /// La lavandería recalculó el precio con su lista al empezar a lavar (el
  /// monto del celular del cliente no se toma como verdad).
  final bool precioConfirmado;

  /// Quién registró la ropa en el mostrador (la ciudad 3D anima a esa persona).
  final String? ropaRecibidaPor;

  const Pedido({
    required this.id,
    required this.clienteId,
    required this.lavanderiaId,
    required this.lavanderiaNombre,
    required this.prendas,
    required this.notas,
    required this.estado,
    required this.creadoEn,
    required this.tipoEntrega,
    required this.direccionRecojo,
    this.recojoLat,
    this.recojoLng,
    required this.costoPrendas,
    required this.costoEnvio,
    this.modoRopaRegular = ModoCobroRegular.pieza,
    this.cantidadRopaRegular = 0,
    this.repartidorUid,
    this.entregaCompletada = false,
    this.calificacionLavanderia,
    this.calificacionRepartidor,
    this.comentarioCalificacion = '',
    this.etapaReparto = EtapaReparto.aceptado,
    this.repartidorNombre = '',
    this.repartidorTelefono = '',
    this.repartidorLat,
    this.repartidorLng,
    this.repartidorActualizadoEn,
    this.tieneComprobante = false,
    this.clienteNombre = '',
    this.ropaRecibidaEn,
    this.precioConfirmado = false,
    this.ropaRecibidaPor,
  });

  int get totalPrendas => prendas.values.fold(0, (a, b) => a + b);
  double get costoTotal => costoPrendas + costoEnvio;
  bool get necesitaRepartidor => tipoEntrega == TipoEntrega.recojoDomicilio;

  /// Minutos que lleva el pedido esperando repartidor (0 si ya tiene o no aplica).
  int get minutosSinRepartidor {
    if (!necesitaRepartidor || repartidorUid != null || creadoEn == null)
      return 0;
    return DateTime.now().difference(creadoEn!).inMinutes;
  }

  /// Umbral a partir del cual se avisa que nadie tomó el encargo.
  static const minutosAlertaSinRepartidor = 15;
  bool get sinRepartidorPreocupante =>
      minutosSinRepartidor >= minutosAlertaSinRepartidor;

  /// La lavandería solo debe empezar a lavar cuando la ropa ya llegó.
  bool get ropaLlegoALavanderia =>
      !necesitaRepartidor ||
      entregaCompletada ||
      (repartidorUid != null &&
          etapaReparto.index >= EtapaReparto.enLavanderia.index);

  /// La ropa ya está físicamente en la lavandería: la trajo el repartidor
  /// o el empleado confirmó que el cliente la dejó (los pedidos viejos que ya
  /// avanzaron de "recibido" también cuentan).
  bool get ropaRecibida => necesitaRepartidor
      ? ropaLlegoALavanderia
      : (ropaRecibidaEn != null || estado != EstadoPedido.recibido);

  String get resumenRopaRegular {
    switch (modoRopaRegular) {
      case ModoCobroRegular.pieza:
        return '';
      case ModoCobroRegular.docena:
        return '${cantidadRopaRegular.toStringAsFixed(1)} docena(s) de ropa regular';
      case ModoCobroRegular.kilo:
        return '${cantidadRopaRegular.toStringAsFixed(1)} kg de ropa regular';
    }
  }

  factory Pedido.fromMap(String id, Map<String, dynamic> map) {
    return Pedido(
      id: id,
      clienteId: map['clienteId'] as String? ?? '',
      lavanderiaId: map['lavanderiaId'] as String? ?? '',
      lavanderiaNombre: map['lavanderiaNombre'] as String? ?? '',
      prendas: Map<String, int>.from(map['prendas'] as Map? ?? {}),
      notas: map['notas'] as String? ?? '',
      estado: estadoPedidoFromString(map['estado'] as String? ?? 'recibido'),
      creadoEn: (map['creadoEn'] as Timestamp?)?.toDate(),
      tipoEntrega: tipoEntregaFromString(
        map['tipoEntrega'] as String? ?? 'clienteLleva',
      ),
      direccionRecojo: map['direccionRecojo'] as String? ?? '',
      recojoLat: (map['recojoLat'] as num?)?.toDouble(),
      recojoLng: (map['recojoLng'] as num?)?.toDouble(),
      costoPrendas: (map['costoPrendas'] as num?)?.toDouble() ?? 0,
      costoEnvio: (map['costoEnvio'] as num?)?.toDouble() ?? 0,
      modoRopaRegular: modoCobroRegularFromString(
        map['modoRopaRegular'] as String? ?? 'pieza',
      ),
      cantidadRopaRegular:
          (map['cantidadRopaRegular'] as num?)?.toDouble() ?? 0,
      repartidorUid: map['repartidorUid'] as String?,
      entregaCompletada: map['entregaCompletada'] as bool? ?? false,
      calificacionLavanderia: (map['calificacionLavanderia'] as num?)?.toInt(),
      calificacionRepartidor: (map['calificacionRepartidor'] as num?)?.toInt(),
      comentarioCalificacion: map['comentarioCalificacion'] as String? ?? '',
      etapaReparto: etapaRepartoFromString(map['etapaReparto'] as String?),
      repartidorNombre: map['repartidorNombre'] as String? ?? '',
      repartidorTelefono: map['repartidorTelefono'] as String? ?? '',
      repartidorLat: (map['repartidorLat'] as num?)?.toDouble(),
      repartidorLng: (map['repartidorLng'] as num?)?.toDouble(),
      repartidorActualizadoEn: (map['repartidorActualizadoEn'] as Timestamp?)
          ?.toDate(),
      tieneComprobante: map['tieneComprobante'] as bool? ?? false,
      clienteNombre: map['clienteNombre'] as String? ?? '',
      ropaRecibidaEn: map['ropaRecibidaEn'] is Timestamp
          ? (map['ropaRecibidaEn'] as Timestamp).toDate()
          : null,
      precioConfirmado: map['precioConfirmado'] as bool? ?? false,
      ropaRecibidaPor: map['ropaRecibidaPor'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clienteId': clienteId,
      'lavanderiaId': lavanderiaId,
      'lavanderiaNombre': lavanderiaNombre,
      'prendas': prendas,
      'notas': notas,
      'estado': estado.name,
      'creadoEn': FieldValue.serverTimestamp(),
      'tipoEntrega': tipoEntrega.name,
      'direccionRecojo': direccionRecojo,
      'recojoLat': recojoLat,
      'recojoLng': recojoLng,
      'costoPrendas': costoPrendas,
      'costoEnvio': costoEnvio,
      'modoRopaRegular': modoRopaRegular.name,
      'cantidadRopaRegular': cantidadRopaRegular,
      'repartidorUid': repartidorUid,
      'entregaCompletada': entregaCompletada,
      'calificacionLavanderia': calificacionLavanderia,
      'calificacionRepartidor': calificacionRepartidor,
      'comentarioCalificacion': comentarioCalificacion,
    };
  }
}
