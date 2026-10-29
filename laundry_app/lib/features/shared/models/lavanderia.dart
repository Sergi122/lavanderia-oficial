import 'horario_atencion.dart';

class Lavanderia {
  final String id;
  final String nombre;
  final String direccion;
  final double lat;
  final double lng;
  final List<String> servicios;
  final Map<String, double> precios;

  /// Ilustración elegida para cada servicio (id de assets/prendas).
  final Map<String, String> iconosServicios;
  final double costoEnvio;

  /// Bs por cada km de recojo por encima de [kmIncluidosEnvio]; 0 = tarifa fija.
  final double costoKmExtra;
  static const kmIncluidosEnvio = 3.0;
  final bool entregaDomicilio;
  final String propietarioUid;
  final List<String> fotosBase64;

  /// Descuento por volumen: sube este % por cada docena completa de ropa
  /// regular en el pedido (sin importar el tipo de prenda, se cuentan todas
  /// juntas), hasta el tope [descuentoMaximoPorcentaje]. null = esa
  /// lavandería no ofrece descuento por volumen.
  final double? descuentoPorDocena;
  final double? descuentoMaximoPorcentaje;
  final double? precioKg;
  final bool activo;
  final String descripcion;
  final HorarioAtencion horarioAtencion;

  /// Panel del dashboard del admin: no usa la foto real (se ve mal si se
  /// agranda más de su resolución) — el admin elige un tema de color y un
  /// emoji decorativo para su propio panel interno.
  final String temaPanel;
  final String iconoPanel;

  const Lavanderia({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.lat,
    required this.lng,
    required this.servicios,
    required this.precios,
    this.iconosServicios = const {},
    required this.costoEnvio,
    this.costoKmExtra = 0,
    required this.entregaDomicilio,
    this.propietarioUid = '',
    this.fotosBase64 = const [],
    this.descuentoPorDocena,
    this.descuentoMaximoPorcentaje,
    this.precioKg,
    this.activo = true,
    this.descripcion = '',
    this.horarioAtencion = const HorarioAtencion(
      dias: [],
      horaApertura: '',
      horaCierre: '',
    ),
    this.temaPanel = 'aqua',
    this.iconoPanel = '🧺',
  });

  factory Lavanderia.fromMap(String id, Map<String, dynamic> map) {
    return Lavanderia(
      id: id,
      nombre: map['nombre'] as String? ?? '',
      direccion: map['direccion'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      servicios: (map['servicios'] as List?)?.cast<String>() ?? const [],
      precios:
          (map['precios'] as Map?)?.map(
            (key, value) => MapEntry(key as String, (value as num).toDouble()),
          ) ??
          const {},
      iconosServicios:
          (map['iconosServicios'] as Map?)?.map(
            (key, value) => MapEntry(key as String, value as String),
          ) ??
          const {},
      costoEnvio: (map['costoEnvio'] as num?)?.toDouble() ?? 0,
      costoKmExtra: (map['costoKmExtra'] as num?)?.toDouble() ?? 0,
      entregaDomicilio: map['entregaDomicilio'] as bool? ?? false,
      propietarioUid: map['propietarioUid'] as String? ?? '',
      fotosBase64: (map['fotosBase64'] as List?)?.cast<String>() ?? const [],
      descuentoPorDocena: (map['descuentoPorDocena'] as num?)?.toDouble(),
      descuentoMaximoPorcentaje: (map['descuentoMaximoPorcentaje'] as num?)
          ?.toDouble(),
      precioKg: (map['precioKg'] as num?)?.toDouble(),
      activo: map['activo'] as bool? ?? true,
      descripcion: map['descripcion'] as String? ?? '',
      // Antes horarioAtencion era texto libre; si un documento viejo todavía
      // lo tiene así, no truena — simplemente se trata como vacío y el admin
      // lo vuelve a poner una vez con el selector nuevo.
      horarioAtencion: HorarioAtencion.fromMap(
        map['horarioAtencion'] is Map
            ? Map<String, dynamic>.from(map['horarioAtencion'] as Map)
            : null,
      ),
      temaPanel: map['temaPanel'] as String? ?? 'aqua',
      iconoPanel: map['iconoPanel'] as String? ?? '🧺',
    );
  }

  bool get ofreceDescuentoPorDocena =>
      descuentoPorDocena != null && descuentoPorDocena! > 0;

  /// % de descuento que corresponde para esta cantidad de piezas de ropa
  /// regular (mezcladas, no importa el tipo): sube [descuentoPorDocena] por
  /// cada docena completa, sin pasar el tope [descuentoMaximoPorcentaje].
  double descuentoParaPiezas(int piezas) {
    if (!ofreceDescuentoPorDocena) return 0;
    final docenasCompletas = piezas ~/ 12;
    final calculado = docenasCompletas * descuentoPorDocena!;
    final tope = descuentoMaximoPorcentaje ?? calculado;
    return calculado > tope ? tope : calculado;
  }

  /// Costo del recojo según la distancia (km por calle, aproximada) entre el
  /// cliente y la lavandería.
  double costoEnvioPara(double km) {
    final extra =
        (km - kmIncluidosEnvio).clamp(0, double.infinity) * costoKmExtra;
    return (costoEnvio + extra).roundToDouble();
  }
}
