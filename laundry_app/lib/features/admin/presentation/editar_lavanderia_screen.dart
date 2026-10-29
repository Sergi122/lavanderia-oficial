import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../client/data/apertura_lavanderia_repository.dart';
import '../../client/data/lavanderia_repository.dart';
import '../../shared/models/horario_atencion.dart';
import '../../shared/models/lavanderia.dart';
import '../../shared/models/tema_panel.dart';
import '../../shared/widgets/icono_prenda.dart';

const _catalogoServicios = ['Lavado', 'Secado', 'Planchado', 'Lavado en seco'];
const _nombresDiasCorto = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

TimeOfDay? _parseHora(String hhmm) {
  final partes = hhmm.split(':');
  if (partes.length != 2) return null;
  final h = int.tryParse(partes[0]);
  final m = int.tryParse(partes[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

/// Formato canónico "HH:mm" en 24h, igual para todas las lavanderías sin
/// importar el idioma/configuración regional del celular del admin.
String _formatHora(TimeOfDay hora) =>
    '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

class _ItemPrecio {
  String nombre;
  String icono;
  final TextEditingController precioCtrl;

  _ItemPrecio({
    required this.nombre,
    required this.icono,
    required String precioInicial,
  }) : precioCtrl = TextEditingController(text: precioInicial);
}

class _ResultadoServicio {
  final String nombre;
  final String icono;
  final String precio;
  _ResultadoServicio(this.nombre, this.icono, this.precio);
}

class EditarLavanderiaScreen extends ConsumerWidget {
  const EditarLavanderiaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final lavanderiaId = appUser?.lavanderiaId;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar mi lavandería')),
      body: lavanderiaId == null
          ? const Center(child: Text('No tienes una lavandería asignada.'))
          : Consumer(
              builder: (context, ref, _) {
                final lavanderiaAsync = ref.watch(
                  lavanderiaPorIdProvider(lavanderiaId),
                );
                return lavanderiaAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (lavanderia) => lavanderia == null
                      ? const Center(
                          child: Text('No se encontró tu lavandería.'),
                        )
                      : _FormularioEdicion(lavanderia: lavanderia),
                );
              },
            ),
    );
  }
}

class _FormularioEdicion extends ConsumerStatefulWidget {
  final Lavanderia lavanderia;
  const _FormularioEdicion({required this.lavanderia});

  @override
  ConsumerState<_FormularioEdicion> createState() => _FormularioEdicionState();
}

class _FormularioEdicionState extends ConsumerState<_FormularioEdicion> {
  late final _servicios = <String>{...widget.lavanderia.servicios};
  late final _descripcionCtrl = TextEditingController(
    text: widget.lavanderia.descripcion,
  );
  late final _diasAtencion = <int>{...widget.lavanderia.horarioAtencion.dias};
  late TimeOfDay? _horaApertura = _parseHora(
    widget.lavanderia.horarioAtencion.horaApertura,
  );
  late TimeOfDay? _horaCierre = _parseHora(
    widget.lavanderia.horarioAtencion.horaCierre,
  );
  late final _costoKmExtraCtrl = TextEditingController(
    text: widget.lavanderia.costoKmExtra == 0
        ? ''
        : widget.lavanderia.costoKmExtra.toStringAsFixed(1),
  );
  late final _costoEnvioCtrl = TextEditingController(
    text: widget.lavanderia.costoEnvio.toStringAsFixed(0),
  );
  late final _descuentoPorDocenaCtrl = TextEditingController(
    text: widget.lavanderia.descuentoPorDocena?.toStringAsFixed(0) ?? '',
  );
  late final _descuentoMaximoCtrl = TextEditingController(
    text: widget.lavanderia.descuentoMaximoPorcentaje?.toStringAsFixed(0) ?? '',
  );
  late final _precioKgCtrl = TextEditingController(
    text: widget.lavanderia.precioKg?.toStringAsFixed(0) ?? '',
  );
  late final List<_ItemPrecio> _itemsPrecio = [
    for (final entry in widget.lavanderia.precios.entries)
      _ItemPrecio(
        nombre: entry.key,
        icono: iconoParaPrenda(
          entry.key,
          elegidos: widget.lavanderia.iconosServicios,
        ),
        precioInicial: entry.value.toStringAsFixed(0),
      ),
  ];
  late bool _entregaDomicilio = widget.lavanderia.entregaDomicilio;
  late String _temaPanel = widget.lavanderia.temaPanel;
  late String _iconoPanel = widget.lavanderia.iconoPanel;
  late final _fotos = <String>[...widget.lavanderia.fotosBase64];
  bool _guardando = false;

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _costoEnvioCtrl.dispose();
    _costoKmExtraCtrl.dispose();
    _descuentoPorDocenaCtrl.dispose();
    _descuentoMaximoCtrl.dispose();
    _precioKgCtrl.dispose();
    for (final item in _itemsPrecio) {
      item.precioCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _agregarServicio() async {
    final resultado = await _mostrarDialogoServicio(context);
    if (resultado == null) return;
    setState(() {
      _itemsPrecio.add(
        _ItemPrecio(
          nombre: resultado.nombre,
          icono: resultado.icono,
          precioInicial: resultado.precio,
        ),
      );
    });
  }

  Future<void> _editarServicio(_ItemPrecio item) async {
    final resultado = await _mostrarDialogoServicio(
      context,
      nombreInicial: item.nombre,
      iconoInicial: item.icono,
      precioInicial: item.precioCtrl.text,
    );
    if (resultado == null) return;
    setState(() {
      item.nombre = resultado.nombre;
      item.icono = resultado.icono;
      item.precioCtrl.text = resultado.precio;
    });
  }

  Future<_ResultadoServicio?> _mostrarDialogoServicio(
    BuildContext context, {
    String? nombreInicial,
    String? iconoInicial,
    String? precioInicial,
  }) {
    final nombreCtrl = TextEditingController(text: nombreInicial ?? '');
    final precioCtrl = TextEditingController(text: precioInicial ?? '');
    String? icono = iconoInicial;

    return showDialog<_ResultadoServicio>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            nombreInicial == null ? 'Nuevo servicio' : 'Editar servicio',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () async {
                    final elegido = await _elegirIcono(dialogContext);
                    if (elegido != null) setDialogState(() => icono = elegido);
                  },
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: AppTheme.fondo,
                    child: IconoPrenda(
                      icono ?? iconoParaPrenda(nombreCtrl.text),
                      tamano: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Toca para elegir el dibujo',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nombreCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del servicio',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: precioCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    prefixText: 'Bs ',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nombreCtrl.text.trim().isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  _ResultadoServicio(
                    nombreCtrl.text.trim(),
                    icono ?? iconoParaPrenda(nombreCtrl.text.trim()),
                    precioCtrl.text.trim(),
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _elegirIcono(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final id in iconosPrenda)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.pop(context, id),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: IconoPrenda(id, tamano: 48),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _agregarFotos() async {
    final resultado = await ImagePicker().pickMultiImage(
      maxWidth: 1024,
      imageQuality: 65,
    );
    if (resultado.isEmpty) return;
    for (final f in resultado) {
      if (_fotos.length >= maxFotosLavanderia) break;
      final bytes = await f.readAsBytes();
      if (bytes.length > maxTamanoFotoBytes) continue;
      setState(() => _fotos.add(base64Encode(bytes)));
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final precios = <String, double>{
        for (final item in _itemsPrecio)
          if (item.nombre.trim().isNotEmpty)
            item.nombre.trim():
                double.tryParse(item.precioCtrl.text.trim()) ?? 0,
      };
      final iconosServicios = <String, String>{
        for (final item in _itemsPrecio)
          if (item.nombre.trim().isNotEmpty) item.nombre.trim(): item.icono,
      };
      await ref
          .read(lavanderiaRepositoryProvider)
          .actualizarLavanderia(
            widget.lavanderia.id,
            servicios: _servicios.toList(),
            precios: precios,
            iconosServicios: iconosServicios,
            descuentoPorDocena: _descuentoPorDocenaCtrl.text.trim().isEmpty
                ? null
                : double.tryParse(_descuentoPorDocenaCtrl.text.trim()),
            descuentoMaximoPorcentaje: _descuentoMaximoCtrl.text.trim().isEmpty
                ? null
                : double.tryParse(_descuentoMaximoCtrl.text.trim()),
            precioKg: _precioKgCtrl.text.trim().isEmpty
                ? null
                : double.tryParse(_precioKgCtrl.text.trim()),
            costoEnvio: double.tryParse(_costoEnvioCtrl.text.trim()) ?? 0,
            costoKmExtra: double.tryParse(_costoKmExtraCtrl.text.trim()) ?? 0,
            entregaDomicilio: _entregaDomicilio,
            fotosBase64: _fotos,
            descripcion: _descripcionCtrl.text.trim(),
            horarioAtencion: HorarioAtencion(
              dias: _diasAtencion.toList()..sort(),
              horaApertura: _horaApertura == null
                  ? ''
                  : _formatHora(_horaApertura!),
              horaCierre: _horaCierre == null ? '' : _formatHora(_horaCierre!),
            ),
            temaPanel: _temaPanel,
            iconoPanel: _iconoPanel,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cambios guardados')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Vista previa en vivo de cómo queda la regla que el admin está
  /// escribiendo ahora mismo: cuánto descuento tendría 1, 2 y 3 docenas.
  String? get _previewDescuentoDocena {
    final porDocena = double.tryParse(_descuentoPorDocenaCtrl.text.trim());
    if (porDocena == null || porDocena <= 0) return null;
    final maximo = double.tryParse(_descuentoMaximoCtrl.text.trim());
    String descuentoEn(int docenas) {
      final calculado = docenas * porDocena;
      final tope = maximo ?? calculado;
      return (calculado > tope ? tope : calculado).toStringAsFixed(0);
    }

    return '1 docena: ${descuentoEn(1)}% · 2 docenas: ${descuentoEn(2)}% · 3 docenas: ${descuentoEn(3)}%';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Descripción de tu negocio',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descripcionCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Cuéntale a tus clientes qué te hace diferente...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Horario de atención',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Mismo formato para todas las lavanderías, así el cliente siempre ve las horas igual.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _nombresDiasCorto.length; i++)
              FilterChip(
                label: Text(_nombresDiasCorto[i]),
                selected: _diasAtencion.contains(i + 1),
                onSelected: (v) => setState(() {
                  if (v) {
                    _diasAtencion.add(i + 1);
                  } else {
                    _diasAtencion.remove(i + 1);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.access_time),
                label: Text(
                  _horaApertura == null
                      ? 'Hora de apertura'
                      : _formatHora(_horaApertura!),
                ),
                onPressed: () async {
                  final elegida = await showTimePicker(
                    context: context,
                    initialTime:
                        _horaApertura ?? const TimeOfDay(hour: 8, minute: 0),
                  );
                  if (elegida != null) setState(() => _horaApertura = elegida);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.access_time_filled),
                label: Text(
                  _horaCierre == null
                      ? 'Hora de cierre'
                      : _formatHora(_horaCierre!),
                ),
                onPressed: () async {
                  final elegida = await showTimePicker(
                    context: context,
                    initialTime:
                        _horaCierre ?? const TimeOfDay(hour: 20, minute: 0),
                  );
                  if (elegida != null) setState(() => _horaCierre = elegida);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Servicios',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _catalogoServicios)
              FilterChip(
                label: Text(s),
                selected: _servicios.contains(s),
                onSelected: (v) => setState(() {
                  if (v) {
                    _servicios.add(s);
                  } else {
                    _servicios.remove(s);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Servicios y precios',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Crea cada prenda o servicio que ofreces, con su emoji y precio.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in _itemsPrecio)
              _TarjetaServicio(
                item: item,
                onTap: () => _editarServicio(item),
                onEliminar: () => setState(() => _itemsPrecio.remove(item)),
              ),
            _TarjetaAgregarServicio(onTap: _agregarServicio),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Descuento por volumen: sube por cada docena completa de ropa regular '
          'en el pedido (mezclando tipos, no importa cuáles), hasta un tope.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _descuentoPorDocenaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '% por docena'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _descuentoMaximoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '% máximo (tope)'),
              ),
            ),
          ],
        ),
        if (_previewDescuentoDocena != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _previewDescuentoDocena!,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _precioKgCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Precio por kg (Bs, opcional)',
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ofrezco recojo a domicilio'),
          value: _entregaDomicilio,
          onChanged: (v) => setState(() => _entregaDomicilio = v),
        ),
        if (_entregaDomicilio)
          TextFormField(
            controller: _costoEnvioCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  'Costo del recojo (Bs, incluye los primeros '
                  '${Lavanderia.kmIncluidosEnvio.toStringAsFixed(0)} km)',
            ),
          ),
        if (_entregaDomicilio) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _costoKmExtraCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Bs extra por cada km adicional (opcional)',
              helperText: 'Vacío = tarifa fija sin importar la distancia',
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Fotos de tu local (${_fotos.length}/$maxFotosLavanderia)',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Los clientes las ven al elegirte en el mapa.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _fotos.length >= maxFotosLavanderia ? null : _agregarFotos,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Agregar foto'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Panel de tu dashboard',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Elige un color y un ícono para tu propio panel (no usa las fotos).',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        Container(
          height: 90,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: gradientePanel(_temaPanel),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(_iconoPanel, style: const TextStyle(fontSize: 40)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tema in temasPanel.keys)
              GestureDetector(
                onTap: () => setState(() => _temaPanel = tema),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: gradientePanel(tema)),
                    border: Border.all(
                      color: _temaPanel == tema
                          ? Colors.black87
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final icono in iconosPanel)
              ChoiceChip(
                label: Text(icono, style: const TextStyle(fontSize: 18)),
                selected: _iconoPanel == icono,
                onSelected: (_) => setState(() => _iconoPanel = icono),
              ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Guardar cambios'),
        ),
      ],
    );
  }
}

class _TarjetaServicio extends StatelessWidget {
  final _ItemPrecio item;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  const _TarjetaServicio({
    required this.item,
    required this.onTap,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: onEliminar,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 16, color: Colors.black45),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconoPrenda(item.icono, tamano: 44),
                const SizedBox(height: 6),
                Text(
                  item.nombre,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: item.precioCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              prefixText: 'Bs ',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAgregarServicio extends StatelessWidget {
  final VoidCallback onTap;

  const _TarjetaAgregarServicio({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 148,
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 32,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 6),
            const Text(
              'Agregar servicio',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
