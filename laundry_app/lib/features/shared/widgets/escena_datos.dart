import 'package:latlong2/latlong.dart';

import '../models/pedido.dart';
import 'escena_lavanderia.dart';

const _dist = Distance();

/// Cuántas casas de clientes caben en la ciudad 3D a la vez.
const maxCasasEscena = 12;

double? _clamp01(double v) => v.isNaN ? null : v.clamp(0.0, 1.0);

/// Progreso REAL (0..1) de la moto de este pedido a partir del GPS del repartidor.
/// - llevando: lo que ya se alejó de la casa hacia la lavandería.
/// - devolviendo: lo que ya se alejó de la lavandería hacia la casa.
/// - recogiendo: el repartidor puede venir de cualquier sitio, así que se mide contra la
///   mayor distancia vista ([distMaxRecoger], mínimo 400 m).
/// Devuelve null si no hay GPS todavía (la escena hace una demostración en bucle).
double? progresoReal(
  Pedido p, {
  required double? lavLat,
  required double? lavLng,
  double distMaxRecoger = 0,
}) {
  if (p.repartidorLat == null ||
      p.repartidorLng == null ||
      p.recojoLat == null ||
      lavLat == null)
    return null;
  final rep = LatLng(p.repartidorLat!, p.repartidorLng!);
  final casa = LatLng(p.recojoLat!, p.recojoLng ?? 0);
  final lav = LatLng(lavLat, lavLng ?? 0);
  switch (p.etapaReparto) {
    case EtapaReparto.aceptado:
      final d0 = distMaxRecoger < 400 ? 400.0 : distMaxRecoger;
      final d = _dist(rep, casa);
      return d < 25 ? 1.0 : _clamp01(1 - d / d0);
    case EtapaReparto.recogido:
      final d0 = _dist(casa, lav);
      if (d0 < 1) return null;
      final d = _dist(rep, lav);
      return d < 25 ? 1.0 : _clamp01(1 - d / d0);
    case EtapaReparto.devolviendo:
      final d0 = _dist(lav, casa);
      if (d0 < 1) return null;
      final d = _dist(rep, casa);
      return d < 25 ? 1.0 : _clamp01(1 - d / d0);
    default:
      return null;
  }
}

/// Distancia (m) del repartidor a la casa mientras va a recoger; para recordar la mayor vista.
double distanciaARecoger(Pedido p) {
  if (p.etapaReparto != EtapaReparto.aceptado ||
      p.repartidorLat == null ||
      p.recojoLat == null)
    return 0;
  return _dist(
    LatLng(p.repartidorLat!, p.repartidorLng!),
    LatLng(p.recojoLat!, p.recojoLng ?? 0),
  );
}

String _corto(Pedido p) =>
    '#${p.id.substring(0, p.id.length < 4 ? p.id.length : 4).toUpperCase()}';

/// Estado visible de la casa del cliente según dónde esté su ropa AHORA (vida real).
({String estado, String texto}) estadoCasa(Pedido p) {
  if (!p.necesitaRepartidor) {
    return switch (p.estado) {
      EstadoPedido.recibido => (estado: 'trae', texto: 'Lleva su ropa'),
      EstadoPedido.enProceso => (estado: 'lavando', texto: 'Lavando y secando'),
      EstadoPedido.listo => (estado: 'lista', texto: 'Lista para recoger'),
      EstadoPedido.entregado => (estado: 'entregada', texto: 'Entregada'),
    };
  }
  if (p.entregaCompletada || p.estado == EstadoPedido.entregado)
    return (estado: 'entregada', texto: '¡Entregada!');
  if (p.repartidorUid == null)
    return (estado: 'esperandoRepartidor', texto: 'Esperando repartidor');
  switch (p.etapaReparto) {
    case EtapaReparto.aceptado:
      return (estado: 'repartidorCamino', texto: 'Repartidor en camino');
    case EtapaReparto.recogido:
      return (estado: 'ropaEnCamino', texto: 'Ropa rumbo a la lavandería');
    case EtapaReparto.enLavanderia:
      return switch (p.estado) {
        EstadoPedido.recibido => (
          estado: 'enLavanderia',
          texto: 'En recepción',
        ),
        EstadoPedido.enProceso => (
          estado: 'lavando',
          texto: 'Lavando y secando',
        ),
        _ => (estado: 'lista', texto: 'Lista, falta el repartidor'),
      };
    case EtapaReparto.devolviendo:
      return (estado: 'devolviendo', texto: 'Esperando su ropa limpia');
    case EtapaReparto.completada:
      return (estado: 'entregada', texto: '¡Entregada!');
  }
}

/// Moto (si la hay) del pedido, con su posición real.
MotoEscena? motoDePedido(
  Pedido p, {
  int slot = 0,
  double? lavLat,
  double? lavLng,
  double distMaxRecoger = 0,
}) {
  if (!p.necesitaRepartidor || p.repartidorUid == null || p.entregaCompletada)
    return null;
  final rol = switch (p.etapaReparto) {
    EtapaReparto.aceptado => RolMoto.recogiendo,
    EtapaReparto.recogido => RolMoto.llevando,
    EtapaReparto.devolviendo => RolMoto.devolviendo,
    _ => null,
  };
  if (rol == null) return null;
  return MotoEscena(
    rol,
    progreso: progresoReal(
      p,
      lavLat: lavLat,
      lavLng: lavLng,
      distMaxRecoger: distMaxRecoger,
    ),
    slot: slot,
  );
}

/// Qué dibuja la ciudad para UN pedido (vista del cliente), sincronizada con la vida real.
EscenaDatos escenaDePedido(
  Pedido p, {
  double? lavLat,
  double? lavLng,
  String nombre = '',
  double distMaxRecoger = 0,
}) {
  final nombreLav = nombre.isNotEmpty ? nombre : p.lavanderiaNombre;
  final c = estadoCasa(p);
  final moto = motoDePedido(
    p,
    lavLat: lavLat,
    lavLng: lavLng,
    distMaxRecoger: distMaxRecoger,
  );
  // la ropa está dentro de la lavandería salvo mientras viaja
  final adentro =
      moto == null &&
      c.estado != 'esperandoRepartidor' &&
      c.estado != 'entregada' &&
      c.estado != 'devolviendo';
  return EscenaDatos(
    colgadas: adentro && p.estado == EstadoPedido.recibido ? 1 : 0,
    lavando: adentro && p.estado == EstadoPedido.enProceso ? 1 : 0,
    ciclo:
        adentro &&
        p.estado ==
            EstadoPedido
                .enProceso, // dura hasta que el empleado la marque lista
    listas:
        adentro &&
            (p.estado == EstadoPedido.listo ||
                p.estado == EstadoPedido.entregado)
        ? 1
        : 0,
    motos: [if (moto != null) moto],
    casas: [CasaEscena(0, c.estado, 'Tu casa · ${c.texto}')],
    paqueteEnCasa: c.estado == 'entregada',
    nombreLavanderia: nombreLav,
    destacarMia: true,
    rutaLarga: true,
  );
}

/// Cada pedido activo ocupa una casa fija mientras dure (hasta [maxCasasEscena]).
class AsignadorCasas {
  final _slots = <String, int>{};

  int? slotPara(String id) {
    final actual = _slots[id];
    if (actual != null) return actual;
    final usados = _slots.values.toSet();
    for (var i = 0; i < maxCasasEscena; i++) {
      if (!usados.contains(i)) return _slots[id] = i;
    }
    return null;
  }

  void liberarExcepto(Set<String> vigentes) =>
      _slots.removeWhere((id, _) => !vigentes.contains(id));
}

/// Resumen de todos los pedidos activos de la lavandería (vista del admin): una casa de
/// cliente por pedido, motos en ruta con su GPS real y el interior con lo que hay ahora.
EscenaDatos escenaDeLavanderia(
  List<Pedido> pedidos,
  String nombre, {
  AsignadorCasas? asignador,
  double? lavLat,
  double? lavLng,
}) {
  final asig = asignador ?? AsignadorCasas();
  final activos =
      pedidos
          .where(
            (p) => p.estado != EstadoPedido.entregado && !p.entregaCompletada,
          )
          .toList()
        ..sort(
          (a, b) => (a.creadoEn ?? DateTime(2000)).compareTo(
            b.creadoEn ?? DateTime(2000),
          ),
        );
  asig.liberarExcepto({for (final p in activos) p.id});
  var colgadas = 0, proceso = 0, listas = 0;
  final motos = <MotoEscena>[], casas = <CasaEscena>[];
  for (final p in activos) {
    final slot = asig.slotPara(p.id);
    final c = estadoCasa(p);
    if (slot != null)
      casas.add(CasaEscena(slot, c.estado, '${_corto(p)} · ${c.texto}'));
    final moto = slot == null
        ? null
        : motoDePedido(p, slot: slot, lavLat: lavLat, lavLng: lavLng);
    if (moto != null) {
      motos.add(moto);
      continue;
    }
    if (!p.ropaLlegoALavanderia) continue;
    switch (p.estado) {
      case EstadoPedido.recibido:
        colgadas++;
      case EstadoPedido.enProceso:
        proceso++;
      case EstadoPedido.listo:
        listas++;
      case EstadoPedido.entregado:
        break;
    }
  }
  return EscenaDatos(
    colgadas: colgadas,
    lavando: (proceso + 1) ~/ 2,
    secando: proceso ~/ 2,
    listas: listas,
    motos: motos.take(maxCasasEscena).toList(),
    casas: casas,
    nombreLavanderia: nombre,
    foco: 'general',
  );
}
