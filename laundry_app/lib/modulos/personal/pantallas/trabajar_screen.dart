import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/verificacion/paso_identidad.dart';

/// Punto de entrada único para "quiero trabajar con ustedes": primero se
/// verifica la identidad de la persona (paso común a los 3 roles) y RECIÉN
/// DESPUÉS se muestran las 3 opciones de rol. Cada opción abre su propio
/// formulario ya con la identidad verificada, sin pedirla de nuevo.
class TrabajarScreen extends StatefulWidget {
  const TrabajarScreen({super.key});

  @override
  State<TrabajarScreen> createState() => _TrabajarScreenState();
}

class _TrabajarScreenState extends State<TrabajarScreen> {
  VerificacionIdentidad? _identidad;

  @override
  Widget build(BuildContext context) {
    if (_identidad == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trabajar con nosotros')),
        body: PasoVerificacionIdentidad(
          onVerificado: (identidad) => setState(() => _identidad = identidad),
        ),
      );
    }

    final identidad = _identidad!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('¿Cómo quieres trabajar?'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _identidad = null),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Identidad verificada: ${identidad.nombreParaMostrar}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Elige una opción',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 14),
          _TarjetaOpcion(
            icono: Icons.badge_outlined,
            titulo: 'Trabajar como empleado',
            descripcion:
                'Sube tu CV y elige en qué lavandería quieres trabajar. '
                'El admin de esa lavandería decide si te acepta.',
            onTap: () =>
                context.push('/cliente/postular-empleado', extra: identidad),
          ),
          const SizedBox(height: 12),
          _TarjetaOpcion(
            icono: Icons.two_wheeler_outlined,
            titulo: 'Repartir pedidos',
            descripcion:
                'Sube la matrícula de tu moto y tu licencia de conducir. '
                'No dependes de una lavandería en particular.',
            onTap: () =>
                context.push('/cliente/postular-repartidor', extra: identidad),
          ),
          const SizedBox(height: 12),
          _TarjetaOpcion(
            icono: Icons.storefront_outlined,
            titulo: 'Registrar mi lavandería',
            descripcion:
                'Marca tu ubicación, servicios y precios. '
                'Un verificador la revisará antes de publicarla en el mapa.',
            onTap: () =>
                context.push('/cliente/abrir-lavanderia', extra: identidad),
          ),
        ],
      ),
    );
  }
}

class _TarjetaOpcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  const _TarjetaOpcion({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
