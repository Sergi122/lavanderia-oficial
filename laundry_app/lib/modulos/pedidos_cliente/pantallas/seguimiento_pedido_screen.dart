import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/contrato/modelos/pedido.dart';
import '../../../core/contrato/datos/lavanderia_repository.dart';
import '../../../core/contrato/datos/pedido_repository.dart';

/// Seguimiento en vivo: dónde va el repartidor, en qué paso está y, al final,
/// la foto de comprobante de la entrega.
class SeguimientoPedidoScreen extends ConsumerWidget {
  final String pedidoId;
  const SeguimientoPedidoScreen({super.key, required this.pedidoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedido = ref.watch(pedidoPorIdProvider(pedidoId)).valueOrNull;
    final lav = pedido == null
        ? null
        : ref.watch(lavanderiaPorIdProvider(pedido.lavanderiaId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento de tu pedido')),
      body: pedido == null
          ? const Center(child: CircularProgressIndicator())
          : _contenido(context, pedido, lav?.lat, lav?.lng),
    );
  }

  Widget _contenido(
    BuildContext context,
    Pedido p,
    double? lavLat,
    double? lavLng,
  ) {
    final puntos = <LatLng>[
      if (p.recojoLat != null) LatLng(p.recojoLat!, p.recojoLng!),
      if (lavLat != null) LatLng(lavLat, lavLng!),
      if (p.repartidorLat != null) LatLng(p.repartidorLat!, p.repartidorLng!),
    ];
    final tieneRepartidor = p.repartidorUid != null;
    final hace = p.repartidorActualizadoEn == null
        ? null
        : DateTime.now().difference(p.repartidorActualizadoEn!).inMinutes;
    final enRuta =
        p.necesitaRepartidor &&
        tieneRepartidor &&
        !p.entregaCompletada &&
        p.etapaReparto != EtapaReparto.enLavanderia &&
        p.etapaReparto != EtapaReparto.completada;

    Marker marcador(LatLng pt, IconData i, Color c) => Marker(
      point: pt,
      width: 40,
      height: 40,
      child: Icon(i, color: c, size: 34),
    );

    final pasos = _pasos(p);
    final titulo = p.entregaCompletada || p.estado == EstadoPedido.entregado
        ? '¡Tu ropa ya está en casa!'
        : p.necesitaRepartidor && !tieneRepartidor
        ? 'Buscando repartidor…'
        : p.necesitaRepartidor && p.etapaReparto != EtapaReparto.enLavanderia
        ? p.etapaReparto.label
        : switch (p.estado) {
            EstadoPedido.recibido => 'Tu ropa llegó a la lavandería',
            EstadoPedido.enProceso => 'Estamos lavando y secando tu ropa',
            EstadoPedido.listo =>
              p.necesitaRepartidor
                  ? 'Lista, esperando al repartidor'
                  : 'Tu ropa está lista para recoger',
            EstadoPedido.entregado => 'Entregado',
          };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const SizedBox(height: 8),
        Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        Text(p.lavanderiaNombre, style: const TextStyle(color: Colors.black54)),
        if (!tieneRepartidor &&
            p.necesitaRepartidor &&
            p.sinRepartidorPreocupante)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Llevamos ${p.minutosSinRepartidor} min sin repartidor. Seguimos avisando a '
              'los repartidores; si prefieres, puedes llevar tu ropa tú mismo.',
              style: const TextStyle(color: Colors.deepOrange, fontSize: 13),
            ),
          ),
        const SizedBox(height: 16),
        _LineaDeTiempo(pasos: pasos),
        if (enRuta && puntos.isNotEmpty) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 190,
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: puntos.length == 1
                      ? null
                      : CameraFit.coordinates(
                          coordinates: puntos,
                          padding: const EdgeInsets.all(44),
                        ),
                  initialCenter: puntos.first,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.losasustadores.laundry_app',
                  ),
                  MarkerLayer(
                    markers: [
                      if (p.recojoLat != null)
                        marcador(
                          LatLng(p.recojoLat!, p.recojoLng!),
                          Icons.home,
                          Colors.orange,
                        ),
                      if (lavLat != null)
                        marcador(
                          LatLng(lavLat, lavLng!),
                          Icons.local_laundry_service,
                          Colors.blue,
                        ),
                      if (p.repartidorLat != null)
                        marcador(
                          LatLng(p.repartidorLat!, p.repartidorLng!),
                          Icons.two_wheeler,
                          Colors.black87,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tieneRepartidor && p.repartidorNombre.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.two_wheeler, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${p.repartidorNombre}'
                      '${hace != null ? ' · ubicación hace ${hace < 1 ? 'instantes' : '$hace min'}' : ''}',
                    ),
                  ),
                  if (p.repartidorTelefono.isNotEmpty)
                    IconButton.filledTonal(
                      onPressed: () =>
                          launchUrl(Uri.parse('tel:${p.repartidorTelefono}')),
                      icon: const Icon(Icons.call),
                      tooltip: 'Llamar al repartidor',
                    ),
                ],
              ),
            ],
            if (p.tieneComprobante) ...[
              const SizedBox(height: 12),
              const Text(
                'Comprobante de entrega',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Consumer(
                builder: (context, ref, _) {
                  final foto = ref.watch(comprobanteEntregaProvider(p.id));
                  return foto.when(
                    loading: () => const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const Text('No se pudo cargar la foto'),
                    data: (b64) => b64 == null
                        ? const SizedBox.shrink()
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(b64),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                  );
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Paso {
  final String titulo;
  final IconData icono;
  final bool hecho;
  final bool actual;
  const _Paso(
    this.titulo,
    this.icono, {
    this.hecho = false,
    this.actual = false,
  });
}

List<_Paso> _pasos(Pedido p) {
  final etapa = p.etapaReparto.index;
  final est = p.estado.index;
  final cerrado = p.estado == EstadoPedido.entregado || p.entregaCompletada;
  // Posición actual dentro de la lista de pasos.
  late final List<(String, IconData)> base;
  late final int actual;
  if (p.necesitaRepartidor) {
    base = [
      ('Repartidor asignado', Icons.person_pin_circle_outlined),
      ('Ropa recogida en tu casa', Icons.shopping_bag_outlined),
      ('Recibida en la lavandería', Icons.storefront_outlined),
      ('Lavando y secando', Icons.local_laundry_service_outlined),
      ('Lista, vuelve a tu casa', Icons.two_wheeler),
      ('Entregada', Icons.home_outlined),
    ];
    if (cerrado) {
      actual = 5;
    } else if (p.repartidorUid == null) {
      actual = -1;
    } else if (etapa == EtapaReparto.aceptado.index) {
      actual = 0;
    } else if (etapa == EtapaReparto.recogido.index) {
      actual = 1;
    } else if (etapa == EtapaReparto.enLavanderia.index) {
      actual = est == EstadoPedido.recibido.index
          ? 2
          : est == EstadoPedido.enProceso.index
          ? 3
          : 4;
    } else {
      actual = 4;
    }
  } else {
    base = [
      ('Recibida', Icons.storefront_outlined),
      ('Lavando y secando', Icons.local_laundry_service_outlined),
      ('Lista para recoger', Icons.check_circle_outline),
      ('Entregada', Icons.home_outlined),
    ];
    actual = est;
  }
  return [
    for (var i = 0; i < base.length; i++)
      _Paso(
        base[i].$1,
        base[i].$2,
        hecho:
            i < actual ||
            (cerrado && i == base.length - 1) ||
            (cerrado && i <= actual),
        actual: !cerrado && i == actual,
      ),
  ];
}

class _LineaDeTiempo extends StatelessWidget {
  final List<_Paso> pasos;
  const _LineaDeTiempo({required this.pasos});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          children: [
            for (var i = 0; i < pasos.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 34,
                      child: Column(
                        children: [
                          _Punto(paso: pasos[i]),
                          if (i < pasos.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: pasos[i].hecho
                                    ? AppTheme.primary
                                    : Colors.black12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 14),
                        child: Text(
                          pasos[i].titulo,
                          style: TextStyle(
                            fontWeight: pasos[i].actual
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: pasos[i].hecho || pasos[i].actual
                                ? AppTheme.tinta
                                : Colors.black45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  final _Paso paso;
  const _Punto({required this.paso});

  @override
  Widget build(BuildContext context) {
    final color = paso.hecho || paso.actual ? AppTheme.primary : Colors.black26;
    final punto = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: paso.hecho ? AppTheme.primary : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(
        paso.hecho ? Icons.check : paso.icono,
        size: 16,
        color: paso.hecho ? Colors.white : color,
      ),
    );
    if (!paso.actual) return punto;
    return punto
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.12, 1.12),
          duration: 800.ms,
        );
  }
}
