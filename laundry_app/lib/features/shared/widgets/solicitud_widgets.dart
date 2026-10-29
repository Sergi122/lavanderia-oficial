import 'dart:convert';

import 'package:flutter/material.dart';

class FotosCarnet extends StatelessWidget {
  final String anversoBase64;
  final String reversoBase64;
  const FotosCarnet({
    super.key,
    required this.anversoBase64,
    required this.reversoBase64,
  });

  Widget _foto(String label, String base64Img) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(base64Img),
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (anversoBase64.isNotEmpty) _foto('Anverso', anversoBase64),
        if (anversoBase64.isNotEmpty && reversoBase64.isNotEmpty)
          const SizedBox(width: 10),
        if (reversoBase64.isNotEmpty) _foto('Reverso', reversoBase64),
      ],
    );
  }
}

class FotosSelfies extends StatelessWidget {
  final String frenteBase64;
  final String izquierdaBase64;
  final String derechaBase64;
  const FotosSelfies({
    super.key,
    required this.frenteBase64,
    required this.izquierdaBase64,
    required this.derechaBase64,
  });

  Widget _foto(String label, String base64Img) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(base64Img),
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (frenteBase64.isEmpty &&
        izquierdaBase64.isEmpty &&
        derechaBase64.isEmpty) {
      return const SizedBox.shrink();
    }
    // Desde que la verificación se hace con cámara en vivo (frente + un solo
    // lado), izquierda y derecha llegan con la misma foto — se muestra una
    // sola vez como "Perfil" para no confundir al verificador.
    final mismoLado =
        izquierdaBase64.isNotEmpty && izquierdaBase64 == derechaBase64;
    return Row(
      children: [
        if (frenteBase64.isNotEmpty) _foto('Frente', frenteBase64),
        if (frenteBase64.isNotEmpty &&
            (izquierdaBase64.isNotEmpty || derechaBase64.isNotEmpty))
          const SizedBox(width: 8),
        if (mismoLado)
          _foto('Perfil', izquierdaBase64)
        else ...[
          if (izquierdaBase64.isNotEmpty) _foto('Perfil izq.', izquierdaBase64),
          if (izquierdaBase64.isNotEmpty && derechaBase64.isNotEmpty)
            const SizedBox(width: 8),
          if (derechaBase64.isNotEmpty) _foto('Perfil der.', derechaBase64),
        ],
      ],
    );
  }
}

class BadgeVerificacionAutomatica extends StatelessWidget {
  final double? distancia;
  final bool? coincide;
  const BadgeVerificacionAutomatica({
    super.key,
    required this.distancia,
    required this.coincide,
  });

  @override
  Widget build(BuildContext context) {
    if (distancia == null) {
      return const Text(
        'Todavía sin resultado de la comparación automática (puede tardar un minuto).',
        style: TextStyle(
          fontSize: 12,
          color: Colors.black45,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final coincideDeVerdad = coincide ?? false;
    final color = coincideDeVerdad ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        coincideDeVerdad
            ? 'Comparación automática: coincide (distancia ${distancia!.toStringAsFixed(2)})'
            : 'Comparación automática: no coincide (distancia ${distancia!.toStringAsFixed(2)}) — revisar con cuidado',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class BadgeDuplicado extends StatelessWidget {
  final bool posibleDuplicado;
  final String motivo;
  const BadgeDuplicado({
    super.key,
    required this.posibleDuplicado,
    required this.motivo,
  });

  @override
  Widget build(BuildContext context) {
    if (!posibleDuplicado) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              motivo.isEmpty
                  ? 'Posible duplicado detectado — revisar con cuidado.'
                  : motivo,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Alerta de discrepancia entre el carnet y la licencia de conducir del
// repartidor (podrían ser fotos de personas distintas).
class BadgeDiscrepanciaDocumentos extends StatelessWidget {
  final bool discrepancia;
  final String motivo;
  const BadgeDiscrepanciaDocumentos({
    super.key,
    required this.discrepancia,
    required this.motivo,
  });

  @override
  Widget build(BuildContext context) {
    if (!discrepancia) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.compare_arrows, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              motivo.isEmpty
                  ? 'El carnet y la licencia de conducir no parecen ser de la misma persona.'
                  : motivo,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> pedirMotivoRechazo(BuildContext context) {
  final motivoCtrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rechazar solicitud'),
      content: TextField(
        controller: motivoCtrl,
        decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(motivoCtrl.text.trim()),
          child: const Text('Rechazar'),
        ),
      ],
    ),
  );
}
