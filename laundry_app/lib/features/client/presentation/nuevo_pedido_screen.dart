import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/routing/rutas.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../shared/models/lavanderia.dart';
import '../../shared/models/pedido.dart';
import '../../shared/models/tipos_prenda.dart';
import '../../shared/widgets/icono_prenda.dart';
import '../../shared/ia/clasificador_prendas.dart';
import '../../shared/presentation/registrar_prendas_screen.dart';
import '../../shared/data/intencion_pedido_repository.dart';
import '../../shared/data/precio_pedido.dart';
import '../data/pedido_repository.dart';

/// Más allá de esta distancia al local no se ofrece recojo a domicilio.
const maxKmRecojo = 30.0;

/// Lo que trae "Realizar pedido": la lavandería y el punto elegido
/// (ubicación actual o casa marcada en el mapa).
class PedidoInicial {
  final Lavanderia lavanderia;
  final LatLng? punto;
  final String? direccion;
  const PedidoInicial({required this.lavanderia, this.punto, this.direccion});
}

class NuevoPedidoScreen extends ConsumerStatefulWidget {
  final Lavanderia lavanderia;
  final LatLng? puntoInicial;
  final String? direccionInicial;
  const NuevoPedidoScreen({
    super.key,
    required this.lavanderia,
    this.puntoInicial,
    this.direccionInicial,
  });

  @override
  ConsumerState<NuevoPedidoScreen> createState() => _NuevoPedidoScreenState();
}

class _NuevoPedidoScreenState extends ConsumerState<NuevoPedidoScreen> {
  late final Map<String, int> _prendas = {for (final tipo in _tipos) tipo: 0};
  final _notasCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _cantidadRegularCtrl = TextEditingController();
  TipoEntrega _tipoEntrega = TipoEntrega.clienteLleva;
  ModoCobroRegular _modoRegular = ModoCobroRegular.pieza;
  bool _enviando = false;
  bool _ubicando = false;
  double? _recojoLat;
  double? _recojoLng;
  double? _kmRecojo;
  String? _uid;
  bool _confirmado = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentAppUserProvider).valueOrNull;
    final ini = widget.puntoInicial;
    if (ini != null) {
      // Punto elegido en "Realizar pedido": si la lavandería recoge a
      // domicilio, ya queda listo para el repartidor.
      _direccionCtrl.text = widget.direccionInicial ?? '';
      _recojoLat = ini.latitude;
      _recojoLng = ini.longitude;
      if (widget.lavanderia.entregaDomicilio) {
        _tipoEntrega = TipoEntrega.recojoDomicilio;
      }
      _calcularKmDePerfil(ini.latitude, ini.longitude);
    } else if (u != null && u.ubicacionLat != null && u.ubicacionLng != null) {
      // Punto de recojo guardado en el perfil: se usa por defecto.
      _direccionCtrl.text = u.direccion;
      _recojoLat = u.ubicacionLat;
      _recojoLng = u.ubicacionLng;
      _calcularKmDePerfil(u.ubicacionLat!, u.ubicacionLng!);
    }
    if (u != null) {
      _uid = u.uid;
      // Casa en construcción en la ciudad 3D del admin mientras arma el pedido.
      ref
          .read(intencionPedidoRepositoryProvider)
          .empezar(
            clienteUid: u.uid,
            clienteNombre: u.nombre,
            lavanderiaId: widget.lavanderia.id,
            lat: _recojoLat ?? u.ubicacionLat,
            lng: _recojoLng ?? u.ubicacionLng,
          )
          .catchError((_) {});
    }
  }

  /// El costo de envío depende de la distancia real, así que también se
  /// calcula para el punto guardado en el perfil.
  Future<void> _calcularKmDePerfil(double lat, double lng) async {
    final lav = widget.lavanderia;
    if (lav.lat == 0 && lav.lng == 0) return;
    try {
      final tramo = await calcularTramo(
        LatLng(lav.lat, lav.lng),
        LatLng(lat, lng),
      );
      if (!mounted) return;
      setState(() {
        if (tramo.km > maxKmRecojo) {
          // Demasiado lejos: se pide otro punto (botón de ubicación actual).
          _recojoLat = null;
          _recojoLng = null;
          _kmRecojo = null;
        } else {
          _kmRecojo = tramo.km;
        }
      });
    } catch (_) {}
  }

  late final _intenciones = ref.read(intencionPedidoRepositoryProvider);

  List<String> get _tipos {
    final precios = widget.lavanderia.precios;
    if (precios.isNotEmpty) return precios.keys.toList();
    return [...prendasEspeciales, ...prendasRegulares];
  }

  /// Prendas delicadas: siempre se cobran por pieza.
  List<String> get _tiposEspeciales =>
      _tipos.where((t) => prendasEspeciales.contains(t)).toList();

  /// Ropa regular: se puede cobrar por pieza, por docena o por kilo.
  List<String> get _tiposRegulares =>
      _tipos.where((t) => !prendasEspeciales.contains(t)).toList();

  bool get _ofreceKilo => widget.lavanderia.precioKg != null;
  bool get _hayModoAlternativo => _ofreceKilo;

  double _precioDe(String tipo) =>
      widget.lavanderia.precios[tipo] ?? precioPorDefecto;

  @override
  void dispose() {
    // Salió sin enviar: la construcción se cancela.
    if (!_confirmado && _uid != null) {
      _intenciones.cancelar(_uid!).catchError((_) {});
    }
    _notasCtrl.dispose();
    _direccionCtrl.dispose();
    _cantidadRegularCtrl.dispose();
    super.dispose();
  }

  int get _totalPrendasEspeciales =>
      _tiposEspeciales.fold(0, (a, t) => a + (_prendas[t] ?? 0));

  int get _totalPrendasRegularesPorPieza =>
      _modoRegular == ModoCobroRegular.pieza
      ? _tiposRegulares.fold(0, (a, t) => a + (_prendas[t] ?? 0))
      : 0;

  double get _cantidadRegularIngresada =>
      double.tryParse(_cantidadRegularCtrl.text.trim()) ?? 0;

  /// Descuento por volumen (mezclando tipos): sube por cada docena completa
  /// de ropa regular en el pedido, hasta el tope que puso el admin.
  double get _descuentoPorcentajeAplicado =>
      widget.lavanderia.descuentoParaPiezas(_totalPrendasRegularesPorPieza);

  double get _costoPrendas => costoPrendasPara(
    widget.lavanderia,
    _prendas,
    _modoRegular,
    _cantidadRegularIngresada,
  );

  double get _costoEnvio {
    if (_tipoEntrega != TipoEntrega.recojoDomicilio) return 0;
    final km = _kmRecojo;
    return km == null
        ? widget.lavanderia.costoEnvio
        : widget.lavanderia.costoEnvioPara(km);
  }

  double get _costoTotal => _costoPrendas + _costoEnvio;

  bool get _hayAlgoQueLavar {
    if (_modoRegular != ModoCobroRegular.pieza && _cantidadRegularIngresada > 0)
      return true;
    return _totalPrendasEspeciales + _totalPrendasRegularesPorPieza > 0;
  }

  Future<void> _usarMiUbicacion() async {
    setState(() => _ubicando = true);
    String? error;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = 'Activa la ubicación (GPS) de tu celular';
      } else {
        var permiso = await Geolocator.checkPermission();
        if (permiso == LocationPermission.denied) {
          permiso = await Geolocator.requestPermission();
        }
        if (permiso == LocationPermission.denied ||
            permiso == LocationPermission.deniedForever) {
          error = 'Necesitamos permiso de ubicación para el recojo';
        } else {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          _recojoLat = pos.latitude;
          _recojoLng = pos.longitude;
          if (_uid != null) {
            _intenciones
                .moverPunto(_uid!, pos.latitude, pos.longitude)
                .catchError((_) {});
          }
          final lav = widget.lavanderia;
          // una lavandería sin coordenadas (0,0) daría un costo absurdo
          if (lav.lat != 0 || lav.lng != 0) {
            final tramo = await calcularTramo(
              LatLng(lav.lat, lav.lng),
              LatLng(pos.latitude, pos.longitude),
            );
            _kmRecojo = tramo.km;
            if (tramo.km > maxKmRecojo) {
              error =
                  'Estás a ${tramo.km.toStringAsFixed(0)} km de esta lavandería: '
                  'es demasiado lejos para el recojo (máx. ${maxKmRecojo.toStringAsFixed(0)} km)';
              _recojoLat = null;
              _recojoLng = null;
              _kmRecojo = null;
            }
          }
        }
      }
    } catch (_) {
      error = 'No pudimos obtener tu ubicación';
    }
    if (!mounted) return;
    setState(() => _ubicando = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _confirmar() async {
    if (!_hayAlgoQueLavar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una prenda')),
      );
      return;
    }
    if (_tipoEntrega == TipoEntrega.recojoDomicilio &&
        _direccionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa la dirección donde recogemos tu ropa'),
        ),
      );
      return;
    }

    if (_tipoEntrega == TipoEntrega.recojoDomicilio && _recojoLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Marca tu ubicación con el botón para que el repartidor llegue',
          ),
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      final prendasAEnviar = <String, int>{
        for (final t in _tiposEspeciales) t: _prendas[t] ?? 0,
        if (_modoRegular == ModoCobroRegular.pieza)
          for (final t in _tiposRegulares) t: _prendas[t] ?? 0,
      }..removeWhere((_, v) => v == 0);

      final pedidoId = await ref
          .read(pedidoRepositoryProvider)
          .crearPedido(
            clienteNombre:
                ref.read(currentAppUserProvider).valueOrNull?.nombre ?? '',
            lavanderiaId: widget.lavanderia.id,
            lavanderiaNombre: widget.lavanderia.nombre,
            prendas: prendasAEnviar,
            notas: _notasCtrl.text.trim(),
            tipoEntrega: _tipoEntrega,
            direccionRecojo: _tipoEntrega == TipoEntrega.recojoDomicilio
                ? _direccionCtrl.text.trim()
                : '',
            recojoLat: _tipoEntrega == TipoEntrega.recojoDomicilio
                ? _recojoLat
                : null,
            recojoLng: _tipoEntrega == TipoEntrega.recojoDomicilio
                ? _recojoLng
                : null,
            costoPrendas: _costoPrendas,
            costoEnvio: _costoEnvio,
            modoRopaRegular: _modoRegular,
            cantidadRopaRegular: _modoRegular == ModoCobroRegular.pieza
                ? 0
                : _cantidadRegularIngresada,
          );
      _confirmado = true;
      if (_uid != null) {
        _intenciones.confirmar(_uid!, pedidoId).catchError((_) {});
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('¡Pedido enviado!')));
        context.go('/cliente');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al enviar: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _tarjetaContador(String tipo) {
    final cantidad = _prendas[tipo] ?? 0;
    return Container(
      width: 158,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconoPrenda(
            tipo,
            tamano: 46,
            elegidos: widget.lavanderia.iconosServicios,
          ),
          const SizedBox(height: 6),
          Text(
            tipo,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            'Bs ${_precioDe(tipo).toStringAsFixed(0)} c/u',
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: cantidad > 0
                    ? () => setState(() => _prendas[tipo] = cantidad - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$cantidad',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _prendas[tipo] = cantidad + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// La IA cuenta las prendas a partir de fotos; el cliente puede corregir
  /// el conteo después con los contadores de siempre.
  Future<void> _identificarConFoto() async {
    final r = await Navigator.of(context).push<Map<String, int>>(
      MaterialPageRoute(
        builder: (_) => RegistrarPrendasScreen(lavanderia: widget.lavanderia),
      ),
    );
    if (r == null || !mounted) return;
    final fuera = <String>[];
    setState(() {
      for (final e in r.entries) {
        if (_prendas.containsKey(e.key)) {
          _prendas[e.key] = e.value;
        } else {
          fuera.add(e.key);
        }
      }
    });
    if (fuera.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Esta lavandería no recibe: ${fuera.join(', ')}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.lavanderia.nombre)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        children: [
          if (clasificadorDisponible) ...[
            OutlinedButton.icon(
              onPressed: _identificarConFoto,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Contar mis prendas con fotos (IA)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (_tiposEspeciales.isNotEmpty) ...[
            const Text(
              'Prendas delicadas (por pieza)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final tipo in _tiposEspeciales) _tarjetaContador(tipo),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_tiposRegulares.isNotEmpty) ...[
            const Text(
              'Ropa regular',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_hayModoAlternativo) ...[
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Por pieza'),
                    selected: _modoRegular == ModoCobroRegular.pieza,
                    onSelected: (_) =>
                        setState(() => _modoRegular = ModoCobroRegular.pieza),
                  ),
                  if (_ofreceKilo)
                    ChoiceChip(
                      label: const Text('Por kilo'),
                      selected: _modoRegular == ModoCobroRegular.kilo,
                      onSelected: (_) =>
                          setState(() => _modoRegular = ModoCobroRegular.kilo),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_modoRegular == ModoCobroRegular.pieza) ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final tipo in _tiposRegulares) _tarjetaContador(tipo),
                ],
              ),
              if (_descuentoPorcentajeAplicado > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '🎉 $_totalPrendasRegularesPorPieza piezas = descuento por volumen de '
                    '${_descuentoPorcentajeAplicado.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ] else
              TextField(
                controller: _cantidadRegularCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Peso aproximado (kg)',
                  helperText:
                      'Bs ${widget.lavanderia.precioKg!.toStringAsFixed(0)} por kg',
                ),
              ),
            const SizedBox(height: 12),
          ],
          const Text(
            '¿Cómo prefieres tu entrega?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          RadioGroup<TipoEntrega>(
            groupValue: _tipoEntrega,
            onChanged: (v) => setState(() => _tipoEntrega = v!),
            child: Column(
              children: [
                RadioListTile<TipoEntrega>(
                  contentPadding: EdgeInsets.zero,
                  value: TipoEntrega.clienteLleva,
                  title: const Text('Yo llevo mis prendas'),
                  subtitle: const Text('Vas tú mismo a la lavandería'),
                ),
                RadioListTile<TipoEntrega>(
                  contentPadding: EdgeInsets.zero,
                  value: TipoEntrega.recojoDomicilio,
                  enabled: widget.lavanderia.entregaDomicilio,
                  title: const Text('Recojo a domicilio'),
                  subtitle: Text(
                    widget.lavanderia.entregaDomicilio
                        ? 'Pasamos por tu ropa (+Bs ${widget.lavanderia.costoEnvio.toStringAsFixed(0)})'
                        : 'Esta lavandería aún no ofrece este servicio',
                  ),
                ),
              ],
            ),
          ),
          if (_tipoEntrega == TipoEntrega.recojoDomicilio) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _direccionCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección donde recogemos tu ropa',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _ubicando ? null : _usarMiUbicacion,
              icon: _ubicando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _recojoLat == null
                          ? Icons.my_location
                          : Icons.check_circle,
                      color: _recojoLat == null ? null : Colors.green,
                    ),
              label: Text(
                _recojoLat == null
                    ? 'Usar mi ubicación actual para el recojo'
                    : 'Ubicación marcada (toca para actualizar)',
              ),
            ),
            if (_kmRecojo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Distancia a la lavandería: ${_kmRecojo!.toStringAsFixed(1)} km · '
                  'Envío: Bs ${_costoEnvio.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _notasCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notas para la lavandería (opcional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Bs ${_costoTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    if (_costoEnvio > 0)
                      Text(
                        'incluye Bs ${_costoEnvio.toStringAsFixed(0)} de envío',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _enviando ? null : _confirmar,
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirmar pedido'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
