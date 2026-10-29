import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../client/data/lavanderia_repository.dart';
import '../data/precio_pedido.dart';
import '../ia/clasificador_prendas.dart';
import '../models/lavanderia.dart';
import '../models/pedido.dart';
import '../widgets/icono_prenda.dart';

/// Se puede registrar la ropa cuando está en el mostrador y el precio
/// todavía no se confirmó (el cliente la trajo, o el repartidor ya la dejó).
bool puedeRegistrarPrendas(Pedido p) =>
    p.estado == EstadoPedido.recibido &&
    !p.precioConfirmado &&
    (!p.necesitaRepartidor || p.etapaReparto == EtapaReparto.enLavanderia);

/// Una foto ya clasificada por la IA.
class _Foto {
  final Uint8List bytes;
  final List<PrediccionPrenda> predicciones;
  String? servicioElegido;
  _Foto(this.bytes, this.predicciones);
}

/// El recepcionista fotografía cada prenda; la IA (MobileNetV2 + TFLite)
/// propone el tipo y él confirma o corrige. Al terminar se guardan las
/// prendas contadas y el precio con la lista de la lavandería: el monto del
/// cliente se reemplaza por este.
///
/// Sin [pedido] es el modo cliente: identifica sus prendas con fotos al armar
/// el pedido y devuelve el conteo (Map<String, int>) con Navigator.pop.
class RegistrarPrendasScreen extends ConsumerStatefulWidget {
  final Pedido? pedido;
  final Lavanderia? lavanderia;

  /// Solo para pruebas automáticas: entrega la foto sin abrir la cámara.
  final Future<Uint8List?> Function(ImageSource fuente)? selectorFoto;
  const RegistrarPrendasScreen({
    super.key,
    this.pedido,
    this.lavanderia,
    this.selectorFoto,
  });

  @override
  ConsumerState<RegistrarPrendasScreen> createState() =>
      _RegistrarPrendasScreenState();
}

class _RegistrarPrendasScreenState
    extends ConsumerState<RegistrarPrendasScreen> {
  final _conteo = <String, int>{};
  final _fotos = <_Foto>[];
  bool _analizando = false;
  bool _guardando = false;
  String? _error;
  late final _kgCtrl = TextEditingController(
    text: widget.pedido?.modoRopaRegular == ModoCobroRegular.kilo
        ? widget.pedido!.cantidadRopaRegular.toStringAsFixed(1)
        : '',
  );

  Pedido? get p => widget.pedido;
  bool get _porKilo => p?.modoRopaRegular == ModoCobroRegular.kilo;

  @override
  void dispose() {
    _kgCtrl.dispose();
    super.dispose();
  }

  int get _totalContado => _conteo.values.fold(0, (a, b) => a + b);

  void _sumar(String servicio, int n) => setState(() {
    final v = (_conteo[servicio] ?? 0) + n;
    if (v <= 0) {
      _conteo.remove(servicio);
    } else {
      _conteo[servicio] = v;
    }
  });

  Future<void> _fotografiar(Lavanderia? lav, ImageSource fuente) async {
    final Uint8List? bytes;
    if (widget.selectorFoto != null) {
      bytes = await widget.selectorFoto!(fuente);
    } else {
      final archivo = await ImagePicker().pickImage(
        source: fuente,
        maxWidth: 900,
        imageQuality: 85,
      );
      bytes = await archivo?.readAsBytes();
    }
    if (bytes == null) return;
    setState(() {
      _analizando = true;
      _error = null;
    });
    try {
      final pred = await clasificarPrenda(bytes);
      final foto = _Foto(bytes, pred);
      // Si la IA está segura, se cuenta sola; si no, espera que el
      // recepcionista elija entre las opciones.
      if (pred.isNotEmpty && pred.first.confianza >= confianzaMinima) {
        foto.servicioElegido = servicioParaClase(lav, pred.first.clase);
        _sumar(foto.servicioElegido!, 1);
      }
      setState(() => _fotos.insert(0, foto));
    } catch (e) {
      setState(() => _error = 'No se pudo analizar la foto: $e');
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  void _elegir(_Foto f, String servicio) {
    if (f.servicioElegido != null) _sumar(f.servicioElegido!, -1);
    f.servicioElegido = servicio;
    _sumar(servicio, 1);
  }

  Future<String?> _elegirOtro(Lavanderia? lav) {
    final opciones = <String>{
      ...?lav?.precios.keys,
      ...nombrePorClase.values,
    }.toList();
    return showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          padding: const EdgeInsets.all(14),
          childAspectRatio: 1.05,
          children: [
            for (final o in opciones)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.pop(c, o),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconoPrenda(
                      o,
                      tamano: 46,
                      elegidos: lav?.iconosServicios ?? const {},
                    ),
                    const SizedBox(height: 4),
                    Text(
                      o,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _costo(Lavanderia? lav) {
    if (lav == null) return p?.costoPrendas ?? 0;
    final kg = double.tryParse(_kgCtrl.text.replaceAll(',', '.')) ?? 0;
    return costoPrendasPara(
      lav,
      _conteo,
      p?.modoRopaRegular ?? ModoCobroRegular.pieza,
      kg,
    );
  }

  Future<void> _confirmar(Lavanderia? lav) async {
    if (lav == null) return;
    final p = this.p;
    if (p == null) {
      Navigator.pop(context, Map<String, int>.of(_conteo));
      return;
    }
    setState(() => _guardando = true);
    try {
      final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
      final kg = double.tryParse(_kgCtrl.text.replaceAll(',', '.'));
      await ref.read(firestoreProvider).collection('pedidos').doc(p.id).update({
        'prendas': _conteo,
        'costoPrendas': _costo(lav),
        'precioConfirmado': true,
        'prendasPorIA': _fotos.where((f) => f.servicioElegido != null).length,
        if (_porKilo && kg != null) 'cantidadRopaRegular': kg,
        if (p.ropaRecibidaEn == null)
          'ropaRecibidaEn': FieldValue.serverTimestamp(),
        if (p.ropaRecibidaEn == null) 'ropaRecibidaPor': uid,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = this.p;
    final lav =
        widget.lavanderia ??
        (p == null
            ? null
            : ref.watch(lavanderiaPorIdProvider(p.lavanderiaId)).valueOrNull);
    final elegidos = lav?.iconosServicios ?? const <String, String>{};
    final costo = _costo(lav);
    final declarado = (p?.prendas ?? const <String, int>{}).entries
        .where((e) => e.value > 0)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.fondo,
      appBar: AppBar(
        title: Text(
          p == null
              ? 'Identificar mis prendas'
              : 'Registrar prendas · #${p.id.substring(0, 5).toUpperCase()}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          if (p != null) ...[
            _Tarjeta(
              titulo: p.clienteNombre.isEmpty
                  ? 'Lo que declaró el cliente'
                  : 'Lo que declaró ${p.clienteNombre.split(' ').first}',
              child: declarado.isEmpty
                  ? const Text('Sin prendas declaradas.')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in declarado)
                          Chip(
                            avatar: IconoPrenda(
                              e.key,
                              tamano: 22,
                              elegidos: elegidos,
                            ),
                            label: Text('${e.value} · ${e.key}'),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.done_all, size: 18),
                          label: const Text('Usar esto como conteo'),
                          onPressed: () => setState(() {
                            _conteo
                              ..clear()
                              ..addEntries(declarado);
                          }),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
          ],
          _Tarjeta(
            titulo: 'Reconocimiento con IA',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!clasificadorDisponible)
                  const Text(
                    'La IA no está disponible en este dispositivo: cuenta las prendas a mano.',
                  )
                else ...[
                  const Text(
                    'Saca una foto de cada prenda, extendida y con buena luz. '
                    'La IA propone el tipo; tú confirmas o corriges.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _analizando
                              ? null
                              : () => _fotografiar(lav, ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Fotografiar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _analizando
                            ? null
                            : () => _fotografiar(lav, ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                    ],
                  ),
                ],
                if (_analizando)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                for (final f in _fotos)
                  _FotoClasificada(
                    foto: f,
                    lav: lav,
                    onElegir: (s) => _elegir(f, s),
                    onOtra: () async {
                      final s = await _elegirOtro(lav);
                      if (s != null) _elegir(f, s);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Tarjeta(
            titulo: 'Conteo registrado ($_totalContado prendas)',
            child: Column(
              children: [
                for (final e in _conteo.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconoPrenda(e.key, tamano: 38, elegidos: elegidos),
                    title: Text(e.key),
                    subtitle: Text(
                      'Bs ${(lav?.precios[e.key] ?? precioPorDefecto).toStringAsFixed(0)} c/u'
                      '${p != null && (p.prendas[e.key] ?? 0) != e.value ? ' · el cliente dijo ${p.prendas[e.key] ?? 0}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _sumar(e.key, -1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '${e.value}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          onPressed: () => _sumar(e.key, 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final s = await _elegirOtro(lav);
                    if (s != null) _sumar(s, 1);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar a mano'),
                ),
                if (_porKilo)
                  TextField(
                    controller: _kgCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Peso real de la ropa regular',
                      suffixText: 'kg',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bs ${costo.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      p == null
                          ? 'Estimado con la lista de la lavandería'
                          : 'El cliente calculó Bs ${p.costoPrendas.toStringAsFixed(0)} (sin envío)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed:
                    _guardando || lav == null || _totalContado == 0 && !_porKilo
                    ? null
                    : () => _confirmar(lav),
                icon: const Icon(Icons.check),
                label: Text(
                  _guardando
                      ? 'Guardando…'
                      : (p == null ? 'Usar este conteo' : 'Confirmar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Tarjeta({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _FotoClasificada extends StatelessWidget {
  final _Foto foto;
  final Lavanderia? lav;
  final void Function(String servicio) onElegir;
  final VoidCallback onOtra;
  const _FotoClasificada({
    required this.foto,
    required this.lav,
    required this.onElegir,
    required this.onOtra,
  });

  @override
  Widget build(BuildContext context) {
    final top = foto.predicciones.take(3).toList();
    final segura = top.isNotEmpty && top.first.confianza >= confianzaMinima;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              foto.bytes,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foto.servicioElegido ??
                      (segura ? '' : 'No estoy segura, ¿qué prenda es?'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final pr in top)
                      ChoiceChip(
                        avatar: IconoPrenda(pr.clase, tamano: 20),
                        label: Text(
                          '${nombrePorClase[pr.clase] ?? pr.clase} ${(pr.confianza * 100).round()}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected:
                            foto.servicioElegido ==
                            servicioParaClase(lav, pr.clase),
                        onSelected: (_) =>
                            onElegir(servicioParaClase(lav, pr.clase)),
                      ),
                    ActionChip(
                      label: const Text('Otra', style: TextStyle(fontSize: 12)),
                      onPressed: onOtra,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
