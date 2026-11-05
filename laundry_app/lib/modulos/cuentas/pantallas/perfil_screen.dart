import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/legal/legal_screens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/sesion/auth_repository.dart';
import '../../../core/contrato/modelos/solicitud_empleado.dart';
import '../../../core/contrato/modelos/solicitud_lavanderia.dart';
import '../../../core/contrato/modelos/solicitud_repartidor.dart';
import '../../../core/contrato/datos/apertura_lavanderia_repository.dart';
import '../../../core/contrato/datos/empleo_repository.dart';
import '../../../core/contrato/datos/postulacion_repartidor_repository.dart';
import '../../../core/marcos/navegacion_cliente.dart';
import '../../../core/contrato/modelos/app_user.dart';

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final solicitudAsync = ref.watch(solicitudPropiaProvider);
    final solicitudRepartidorAsync = ref.watch(
      solicitudRepartidorPropiaProvider,
    );
    final solicitudEmpleadoAsync = ref.watch(solicitudEmpleadoPropiaProvider);

    final cargandoSolicitudes =
        solicitudAsync.isLoading ||
        solicitudRepartidorAsync.isLoading ||
        solicitudEmpleadoAsync.isLoading;
    final ningunaSolicitudIntentada =
        !cargandoSolicitudes &&
        solicitudAsync.valueOrNull == null &&
        solicitudRepartidorAsync.valueOrNull == null &&
        solicitudEmpleadoAsync.valueOrNull == null;

    final esClienteNav =
        ref.watch(currentAppUserProvider).valueOrNull?.role == UserRole.cliente;
    return Scaffold(
      bottomNavigationBar: esClienteNav
          ? const NavegacionCliente(actual: 3)
          : null,
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appUser?.nombre ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appUser?.email ?? '',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (ningunaSolicitudIntentada)
            const _TarjetaQuieroTrabajar()
          else ...[
            _SeccionEmpleado(solicitudAsync: solicitudEmpleadoAsync),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _SeccionLavanderiaPropia(solicitudAsync: solicitudAsync),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _SeccionRepartidor(solicitudAsync: solicitudRepartidorAsync),
          ],
          const SizedBox(height: 16),
          const SeccionPrivacidadCuenta(),
        ],
      ),
    );
  }
}

class _TarjetaQuieroTrabajar extends StatelessWidget {
  const _TarjetaQuieroTrabajar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Quieres trabajar con nosotros?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Puedes ser empleado de una lavandería, repartidor de pedidos, o '
            'registrar tu propia lavandería. Primero verificamos que eres tú '
            'con tu carnet y la cámara — luego eliges qué quieres hacer.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/cliente/trabajar'),
              child: const Text('Empezar verificación'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionEmpleado extends StatelessWidget {
  final AsyncValue<SolicitudEmpleado?> solicitudAsync;
  const _SeccionEmpleado({required this.solicitudAsync});

  @override
  Widget build(BuildContext context) {
    return solicitudAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('No se pudo cargar tu solicitud: $e'),
      data: (solicitud) {
        if (solicitud == null ||
            solicitud.estado == EstadoSolicitud.rechazada) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Quieres trabajar como empleado en una lavandería?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sube tu CV, tu carnet y unas selfies. El admin de esa lavandería '
                'confirma tu identidad y decide si te acepta.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              if (solicitud?.estado == EstadoSolicitud.rechazada) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    solicitud!.motivoRechazo.isEmpty
                        ? 'Tu solicitud anterior fue rechazada.'
                        : 'Tu solicitud anterior fue rechazada: ${solicitud.motivoRechazo}',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/cliente/postular-empleado'),
                  child: Text(
                    solicitud?.estado == EstadoSolicitud.rechazada
                        ? 'Volver a intentar'
                        : 'Postularme como empleado',
                  ),
                ),
              ),
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu solicitud para ser empleado está en revisión.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      solicitud.estado.label,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeccionLavanderiaPropia extends StatelessWidget {
  final AsyncValue<SolicitudLavanderia?> solicitudAsync;
  const _SeccionLavanderiaPropia({required this.solicitudAsync});

  @override
  Widget build(BuildContext context) {
    return solicitudAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('No se pudo cargar tu solicitud: $e'),
      data: (solicitud) {
        if (solicitud == null ||
            solicitud.estado == EstadoSolicitud.rechazada) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Tienes tu propia lavandería?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Regístrala con su ubicación, servicios y carnet de propietario. '
                'Un verificador la revisará antes de publicarla en el mapa.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              if (solicitud?.estado == EstadoSolicitud.rechazada) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    solicitud!.motivoRechazo.isEmpty
                        ? 'Tu solicitud anterior fue rechazada.'
                        : 'Tu solicitud anterior fue rechazada: ${solicitud.motivoRechazo}',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/cliente/abrir-lavanderia'),
                  child: Text(
                    solicitud?.estado == EstadoSolicitud.rechazada
                        ? 'Volver a intentar'
                        : 'Abrir mi lavandería',
                  ),
                ),
              ),
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu solicitud para "${solicitud.nombre}" está en revisión.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      solicitud.estado.label,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeccionRepartidor extends StatelessWidget {
  final AsyncValue<SolicitudRepartidor?> solicitudAsync;
  const _SeccionRepartidor({required this.solicitudAsync});

  @override
  Widget build(BuildContext context) {
    return solicitudAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('No se pudo cargar tu solicitud: $e'),
      data: (solicitud) {
        if (solicitud == null ||
            solicitud.estado == EstadoSolicitud.rechazada) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Tienes moto y quieres repartir pedidos?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sube tu carnet y la matrícula de tu moto. Un verificador te aprobará '
                'antes de que puedas aceptar encargos.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              if (solicitud?.estado == EstadoSolicitud.rechazada) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    solicitud!.motivoRechazo.isEmpty
                        ? 'Tu solicitud anterior fue rechazada.'
                        : 'Tu solicitud anterior fue rechazada: ${solicitud.motivoRechazo}',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/cliente/postular-repartidor'),
                  child: Text(
                    solicitud?.estado == EstadoSolicitud.rechazada
                        ? 'Volver a intentar'
                        : 'Repartir pedidos',
                  ),
                ),
              ),
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.hourglass_top, color: AppTheme.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tu solicitud para ser repartidor está en revisión.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
