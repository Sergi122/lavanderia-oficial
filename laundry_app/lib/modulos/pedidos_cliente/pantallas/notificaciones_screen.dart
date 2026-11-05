import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/sesion/auth_repository.dart';
import '../../../core/contrato/datos/soporte_repository.dart';
import '../../../core/contrato/modelos/app_user.dart';
import '../../../core/contrato/modelos/pedido.dart';
import '../../../core/contrato/modelos/ticket_soporte.dart';
import '../../../core/widgets/dashboard_widgets.dart';
import '../../../core/contrato/datos/pedido_repository.dart';
import 'historial_pedidos_screen.dart';
import '../../../core/marcos/navegacion_cliente.dart';

/// Preferencias de avisos guardadas en el documento del usuario.
final _prefsAvisosProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const {});
  return FirebaseFirestore.instance
      .collection('usuarios')
      .doc(uid)
      .snapshots()
      .map((d) => d.data() ?? const {});
});

class _Aviso {
  final IconData icono;
  final String titulo;
  final String detalle;
  final DateTime? fecha;
  final bool urgente;
  const _Aviso(this.icono, this.titulo, this.detalle, this.fecha)
    : urgente = false;
}

/// WF-35 · Notificaciones (RF-54, RF-55): bandeja con los avisos del pedido,
/// de la entrega y de soporte, e interruptores para elegir qué avisos llegan
/// al teléfono (también con la app cerrada).
class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  List<_Aviso> _avisos(List<Pedido> pedidos, List<TicketSoporte> tickets) {
    final out = <_Aviso>[];
    for (final p in pedidos) {
      final cod = codigoPedido(p);
      out.add(
        _Aviso(
          p.estado == EstadoPedido.listo
              ? Icons.check_circle_outline
              : Icons.local_laundry_service_outlined,
          'Tu pedido $cod está ${p.estado.label.toLowerCase()}',
          p.lavanderiaNombre,
          p.ropaRecibidaEn ?? p.creadoEn,
        ),
      );
      if (p.tipoEntrega == TipoEntrega.recojoDomicilio &&
          p.repartidorUid != null &&
          !p.entregaCompletada) {
        out.add(
          _Aviso(
            Icons.two_wheeler_outlined,
            'Entrega de $cod: ${p.etapaReparto.label}',
            p.repartidorNombre.isEmpty ? 'Tu repartidor' : p.repartidorNombre,
            p.repartidorActualizadoEn,
          ),
        );
      }
    }
    for (final t in tickets) {
      if (t.estado == EstadoTicket.resuelto && t.respuesta.isNotEmpty) {
        out.add(
          _Aviso(
            Icons.support_agent_outlined,
            'Respondieron tu ticket: ${t.asunto}',
            t.respuesta,
            t.creadoEn,
          ),
        );
      }
    }
    out.sort(
      (a, b) => (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0)),
    );
    return out;
  }

  Future<void> _guardar(WidgetRef ref, String campo, bool v) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      campo: v,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidos =
        ref.watch(misPedidosProvider).valueOrNull ?? const <Pedido>[];
    final tickets =
        ref.watch(misTicketsProvider).valueOrNull ?? const <TicketSoporte>[];
    final prefs = ref.watch(_prefsAvisosProvider).valueOrNull ?? const {};
    final esRepartidor =
        ref.watch(currentAppUserProvider).valueOrNull?.role ==
        UserRole.repartidor;
    final avisos = _avisos(pedidos, tickets);
    final hora = DateFormat('dd/MM HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      bottomNavigationBar: const NavegacionCliente(actual: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (avisos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: EstadoVacio(
                icono: Icons.notifications_none_rounded,
                mensaje: 'Todavía no tienes avisos.',
              ),
            ),
          for (final a in avisos)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  a.icono,
                  color: a.urgente ? Colors.red : AppTheme.primary,
                ),
                title: Text(a.titulo),
                subtitle: Text(
                  a.detalle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: a.fecha == null
                    ? null
                    : Text(
                        hora.format(a.fecha!),
                        style: const TextStyle(fontSize: 12),
                      ),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Recibir avisos de',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Llegan aunque la app esté cerrada.',
            style: TextStyle(color: Colors.black54),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cambios de estado del pedido'),
            value: prefs['avisosEstado'] as bool? ?? true,
            onChanged: (v) => _guardar(ref, 'avisosEstado', v),
          ),
          if (esRepartidor)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Encargos nuevos (repartidor)'),
              subtitle: const Text(
                'Si pasan 15 minutos sin repartidor, el aviso llega como urgente.',
              ),
              value: prefs['disponibleEncargos'] as bool? ?? true,
              onChanged: (v) => _guardar(ref, 'disponibleEncargos', v),
            ),
        ],
      ),
    );
  }
}
