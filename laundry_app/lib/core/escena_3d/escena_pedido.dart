import 'dart:async';

import 'package:flutter/material.dart';

import '../contrato/modelos/pedido.dart';
import 'escena_datos.dart';
import 'escena_interactiva.dart';
import 'escena_lavanderia.dart';

/// Ciudad 3D de UN pedido, pegada a la vida real: la moto sigue el GPS del repartidor y, al
/// cambiar de etapa (recogida, llegada a la lavandería, entrega), primero LLEGA a su destino
/// y recién después cambia la escena. El lavado/secado dura hasta que el empleado lo marque listo.
class EscenaPedido extends StatefulWidget {
  final Pedido pedido;
  final double? lavLat, lavLng;
  final String? mensaje;
  final double aspectRatio;
  final Widget? encima;
  const EscenaPedido({
    super.key,
    required this.pedido,
    this.lavLat,
    this.lavLng,
    this.mensaje,
    this.aspectRatio = 1.8,
    this.encima,
  });

  @override
  State<EscenaPedido> createState() => _EscenaPedidoState();
}

class _EscenaPedidoState extends State<EscenaPedido> {
  double _distMaxRecoger = 0;
  RolMoto? _llegando; // moto de la etapa anterior terminando su recorrido
  Pedido? _anterior;
  Timer? _timer;

  RolMoto? _rol(Pedido p) {
    if (!p.necesitaRepartidor || p.repartidorUid == null || p.entregaCompletada)
      return null;
    return switch (p.etapaReparto) {
      EtapaReparto.aceptado => RolMoto.recogiendo,
      EtapaReparto.recogido => RolMoto.llevando,
      EtapaReparto.devolviendo => RolMoto.devolviendo,
      _ => null,
    };
  }

  @override
  void initState() {
    super.initState();
    _distMaxRecoger = distanciaARecoger(widget.pedido);
  }

  @override
  void didUpdateWidget(covariant EscenaPedido old) {
    super.didUpdateWidget(old);
    final d = distanciaARecoger(widget.pedido);
    if (d > _distMaxRecoger) _distMaxRecoger = d;
    final antes = _rol(old.pedido), ahora = _rol(widget.pedido);
    if (antes != null && antes != ahora) {
      // la moto de la etapa que terminó llega a su destino antes de pasar a lo siguiente
      _anterior = old.pedido;
      _llegando = antes;
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _llegando = null);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    EscenaDatos datos;
    if (_llegando != null && _anterior != null) {
      final prev = escenaDePedido(
        _anterior!,
        lavLat: widget.lavLat,
        lavLng: widget.lavLng,
        distMaxRecoger: _distMaxRecoger,
      );
      datos = EscenaDatos(
        motos: [MotoEscena(_llegando!, progreso: 1, rapido: true)],
        casas: prev.casas,
        nombreLavanderia: prev.nombreLavanderia,
        destacarMia: true,
        rutaLarga: true,
      );
    } else {
      datos = escenaDePedido(
        p,
        lavLat: widget.lavLat,
        lavLng: widget.lavLng,
        distMaxRecoger: _distMaxRecoger,
      );
    }
    return EscenaInteractiva(
      datos: datos,
      mensaje: widget.mensaje,
      aspectRatio: widget.aspectRatio,
      encima: widget.encima,
    );
  }
}
