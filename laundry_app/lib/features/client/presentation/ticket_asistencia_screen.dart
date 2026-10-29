import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../shared/data/soporte_repository.dart';
import '../../shared/models/pedido.dart';
import '../../shared/models/ticket_soporte.dart';
import '../data/pedido_repository.dart';

const _categorias = [
  (Icons.checkroom_outlined, 'Prenda dañada o perdida'),
  (Icons.schedule_outlined, 'Demora en mi pedido'),
  (Icons.two_wheeler_outlined, 'Problema con el repartidor'),
  (Icons.payments_outlined, 'Cobro incorrecto'),
  (Icons.phone_android_outlined, 'Falla de la app'),
  (Icons.help_outline, 'Otro'),
];

/// "Si pasa algo": el cliente abre un ticket (opcionalmente ligado a un
/// pedido) y ve la respuesta del equipo cuando lo resuelven.
class TicketAsistenciaScreen extends ConsumerStatefulWidget {
  const TicketAsistenciaScreen({super.key});

  @override
  ConsumerState<TicketAsistenciaScreen> createState() =>
      _TicketAsistenciaScreenState();
}

class _TicketAsistenciaScreenState
    extends ConsumerState<TicketAsistenciaScreen> {
  final _mensajeCtrl = TextEditingController();
  String? _categoria;
  Pedido? _pedido;
  bool _enviando = false;

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final u = ref.read(currentAppUserProvider).valueOrNull;
    if (u == null) return;
    if (_categoria == null) {
      _aviso('Elige qué pasó');
      return;
    }
    if (_mensajeCtrl.text.trim().length < 10) {
      _aviso('Cuéntanos un poco más (mínimo 10 letras)');
      return;
    }
    setState(() => _enviando = true);
    try {
      await ref
          .read(soporteRepositoryProvider)
          .crearTicket(
            autorUid: u.uid,
            autorNombre: u.nombre,
            lavanderiaId: _pedido?.lavanderiaId ?? '',
            lavanderiaNombre: _pedido?.lavanderiaNombre ?? '',
            asunto: _categoria!,
            mensaje: _mensajeCtrl.text.trim(),
            rolAutor: u.role.name,
            categoria: _categoria!,
            pedidoId: _pedido?.id,
          );
      if (!mounted) return;
      setState(() {
        _categoria = null;
        _pedido = null;
        _mensajeCtrl.clear();
      });
      _aviso('Ticket enviado. Te responderemos aquí mismo.');
    } catch (e) {
      _aviso('No se pudo enviar: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _aviso(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(misPedidosProvider).valueOrNull ?? const [];
    final tickets = ref.watch(misTicketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ticket de asistencia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            '¿Qué pasó?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (icono, texto) in _categorias)
                ChoiceChip(
                  avatar: Icon(icono, size: 18),
                  label: Text(texto),
                  selected: _categoria == texto,
                  onSelected: (_) => setState(() => _categoria = texto),
                ),
            ],
          ),
          if (pedidos.isNotEmpty) ...[
            const SizedBox(height: 18),
            DropdownButtonFormField<String?>(
              initialValue: _pedido?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '¿Sobre qué pedido? (opcional)',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Ninguno')),
                for (final p in pedidos.take(15))
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      '${p.lavanderiaNombre} · ${p.totalPrendas} prendas · ${p.estado.label}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => setState(
                () => _pedido = id == null
                    ? null
                    : pedidos.firstWhere((p) => p.id == id),
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _mensajeCtrl,
            maxLines: 4,
            maxLength: 600,
            decoration: const InputDecoration(
              labelText: 'Describe el problema',
              helperText:
                  'Incluye fechas, prendas o lo que nos ayude a resolverlo',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _enviando ? null : _enviar,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Enviar ticket'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Mis tickets',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          tickets.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('No se pudieron cargar: $e'),
            data: (lista) => lista.isEmpty
                ? const Text(
                    'Aún no abriste ningún ticket.',
                    style: TextStyle(color: Colors.black54),
                  )
                : Column(
                    children: [for (final t in lista) _TicketCard(ticket: t)],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketSoporte ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final abierto = ticket.estado == EstadoTicket.abierto;
    final color = abierto ? Colors.orange.shade800 : Colors.green.shade800;
    final f = ticket.creadoEn;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.asunto,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    abierto ? 'En revisión' : 'Resuelto',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (f != null)
              Text(
                '${f.day}/${f.month}/${f.year} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}'
                '${ticket.lavanderiaNombre.isEmpty ? '' : ' · ${ticket.lavanderiaNombre}'}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            const SizedBox(height: 8),
            Text(ticket.mensaje),
            if (ticket.respuesta.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Respuesta del equipo: ${ticket.respuesta}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
