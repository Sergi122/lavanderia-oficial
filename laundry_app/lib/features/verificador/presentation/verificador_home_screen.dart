import 'dart:convert';

import 'package:flutter/material.dart';

import '../../shared/widgets/dashboard_widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/models/solicitud_lavanderia.dart';
import '../../shared/models/solicitud_repartidor.dart';
import '../../shared/widgets/solicitud_widgets.dart';
import '../data/verificador_repository.dart';

class VerificadorHomeScreen extends ConsumerWidget {
  const VerificadorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: const Column(
          children: [
            PanelHeader(
              rol: 'Verificador',
              subtitulo: 'revisa identidades y solicitudes',
              icono: Icons.verified_user_outlined,
            ),
            PestanasPanel(
              tabs: [
                Tab(text: 'Lavanderías'),
                Tab(text: 'Repartidores'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [_TabLavanderias(), _TabRepartidores()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLavanderias extends ConsumerWidget {
  const _TabLavanderias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudesAsync = ref.watch(solicitudesPendientesProvider);

    return solicitudesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar solicitudes: $e')),
      data: (solicitudes) {
        if (solicitudes.isEmpty) {
          return const Center(
            child: Text(
              'No hay solicitudes pendientes.',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final s in solicitudes)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _SolicitudLavanderiaCard(solicitud: s),
              ),
          ],
        );
      },
    );
  }
}

class _TabRepartidores extends ConsumerWidget {
  const _TabRepartidores();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudesAsync = ref.watch(solicitudesRepartidorPendientesProvider);

    return solicitudesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar solicitudes: $e')),
      data: (solicitudes) {
        if (solicitudes.isEmpty) {
          return const Center(
            child: Text(
              'No hay solicitudes pendientes.',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final s in solicitudes)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _SolicitudRepartidorCard(solicitud: s),
              ),
          ],
        );
      },
    );
  }
}

class _SolicitudLavanderiaCard extends ConsumerWidget {
  final SolicitudLavanderia solicitud;
  const _SolicitudLavanderiaCard({required this.solicitud});

  Future<void> _abrirEnMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${solicitud.lat},${solicitud.lng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              solicitud.nombre,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              solicitud.nit.isEmpty
                  ? 'NIT: no registrado'
                  : 'NIT: ${solicitud.nit}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              solicitud.direccion,
              style: const TextStyle(color: Colors.black54),
            ),
            if (solicitud.nombrePropietario.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Propietario: ${solicitud.nombrePropietario}'
                '${solicitud.ciPropietario.isEmpty ? '' : ' · CI ${solicitud.ciPropietario}'}'
                '${solicitud.telefonoPropietario.isEmpty ? '' : ' · ${solicitud.telefonoPropietario}'}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final serv in solicitud.servicios)
                  Chip(
                    label: Text(serv),
                    backgroundColor: const Color(0xFFEFF6F6),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _abrirEnMaps,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ver ubicación en Google Maps'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Carnet del propietario',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            FotosCarnet(
              anversoBase64: solicitud.carnetAnversoBase64,
              reversoBase64: solicitud.carnetReversoBase64,
            ),
            const SizedBox(height: 14),
            const Text(
              'Selfies de verificación (compara con el carnet)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            FotosSelfies(
              frenteBase64: solicitud.selfieFrenteBase64,
              izquierdaBase64: solicitud.selfieIzquierdaBase64,
              derechaBase64: solicitud.selfieDerechaBase64,
            ),
            const SizedBox(height: 10),
            BadgeVerificacionAutomatica(
              distancia: solicitud.verificacionAutomaticaDistancia,
              coincide: solicitud.verificacionAutomaticaCoincide,
            ),
            BadgeDuplicado(
              posibleDuplicado: solicitud.posibleDuplicado,
              motivo: solicitud.motivoDuplicado,
            ),
            BadgeDuplicado(
              posibleDuplicado: solicitud.pruebaVidaOk == false,
              motivo: 'Prueba de vida: ${solicitud.motivoPruebaVida}',
            ),
            if (solicitud.fotosBase64.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Fotos del local',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: solicitud.fotosBase64.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(solicitud.fotosBase64[index]),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Aquí solo confirmas la identidad de la persona. La revisión '
              'del local (ubicación, NIT, fotos) la hace el superadmin después.',
              style: TextStyle(
                color: Colors.black45,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final motivo = await pedirMotivoRechazo(context);
                      if (motivo == null) return;
                      await ref
                          .read(verificadorRepositoryProvider)
                          .rechazar(solicitud.propietarioUid, motivo);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(verificadorRepositoryProvider)
                        .confirmarIdentidadLavanderia(solicitud.propietarioUid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    child: const Text('Confirmar identidad'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SolicitudRepartidorCard extends ConsumerWidget {
  final SolicitudRepartidor solicitud;
  const _SolicitudRepartidorCard({required this.solicitud});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              solicitud.nombre,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              'CI: ${solicitud.ci} · Cel: ${solicitud.telefono}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Placa de la moto: ${solicitud.placaMoto}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            const Text(
              'Carnet del repartidor',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            FotosCarnet(
              anversoBase64: solicitud.carnetAnversoBase64,
              reversoBase64: solicitud.carnetReversoBase64,
            ),
            const SizedBox(height: 14),
            const Text(
              'Selfies de verificación (compara con el carnet)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            FotosSelfies(
              frenteBase64: solicitud.selfieFrenteBase64,
              izquierdaBase64: solicitud.selfieIzquierdaBase64,
              derechaBase64: solicitud.selfieDerechaBase64,
            ),
            const SizedBox(height: 10),
            BadgeVerificacionAutomatica(
              distancia: solicitud.verificacionAutomaticaDistancia,
              coincide: solicitud.verificacionAutomaticaCoincide,
            ),
            BadgeDuplicado(
              posibleDuplicado: solicitud.posibleDuplicado,
              motivo: solicitud.motivoDuplicado,
            ),
            BadgeDuplicado(
              posibleDuplicado: solicitud.pruebaVidaOk == false,
              motivo: 'Prueba de vida: ${solicitud.motivoPruebaVida}',
            ),
            BadgeDiscrepanciaDocumentos(
              discrepancia: solicitud.discrepanciaDocumentos,
              motivo: solicitud.motivoDiscrepancia,
            ),
            if (solicitud.matriculaMotoBase64.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Matrícula de la moto',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(solicitud.matriculaMotoBase64),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            if (solicitud.licenciaConducirBase64.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Licencia de conducir de motos',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(solicitud.licenciaConducirBase64),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final motivo = await pedirMotivoRechazo(context);
                      if (motivo == null) return;
                      await ref
                          .read(verificadorRepositoryProvider)
                          .rechazarRepartidor(solicitud.uid, motivo);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(verificadorRepositoryProvider)
                        .aprobarRepartidor(solicitud),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    child: const Text('Aprobar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
