import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/data/auth_repository.dart';
import 'textos_legales.dart';

/// Documento completo (`/legal/privacidad` o `/legal/terminos`). Se puede
/// abrir sin sesión, desde el registro.
class DocumentoLegalScreen extends ConsumerWidget {
  final String tipo;
  const DocumentoLegalScreen({super.key, required this.tipo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(documentoLegalProvider(tipo));
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(doc.valueOrNull?.titulo ?? ''),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      body: doc.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (d) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Text(
                  'Actualizado el ${d.actualizado}',
                  style: tema.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(d.intro, style: tema.textTheme.bodyLarge),
                for (final s in d.secciones) ...[
                  const SizedBox(height: 22),
                  Text(
                    s.titulo,
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  for (final p in s.parrafos)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(p, style: const TextStyle(height: 1.45)),
                    ),
                  for (final i in s.items)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(
                            child: Text(
                              i,
                              style: const TextStyle(height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Texto "Acepto la Política de privacidad y los Términos" con enlaces que
/// abren cada documento. Lo usan el registro y [AceptarTerminosScreen].
class TextoAceptoTerminos extends StatelessWidget {
  final Color color;
  final Color colorEnlace;
  const TextoAceptoTerminos({
    super.key,
    this.color = Colors.white70,
    this.colorEnlace = const Color(0xFF8FD7FF),
  });

  @override
  Widget build(BuildContext context) {
    final enlace = TextStyle(
      color: colorEnlace,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: colorEnlace,
    );
    return Text.rich(
      TextSpan(
        style: TextStyle(color: color, fontSize: 13, height: 1.4),
        children: [
          const TextSpan(text: 'Tengo 18 años o más y acepto la '),
          TextSpan(
            text: 'Política de privacidad',
            style: enlace,
            recognizer: TapGestureRecognizer()
              ..onTap = () => context.push('/legal/privacidad'),
          ),
          const TextSpan(text: ' y los '),
          TextSpan(
            text: 'Términos y condiciones',
            style: enlace,
            recognizer: TapGestureRecognizer()
              ..onTap = () => context.push('/legal/terminos'),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

/// Puerta obligatoria: quien no aceptó la versión vigente (cuentas de Google,
/// cuentas anteriores al piloto o tras un cambio de versión) pasa por aquí.
class AceptarTerminosScreen extends ConsumerStatefulWidget {
  const AceptarTerminosScreen({super.key});

  @override
  ConsumerState<AceptarTerminosScreen> createState() =>
      _AceptarTerminosScreenState();
}

class _AceptarTerminosScreenState extends ConsumerState<AceptarTerminosScreen> {
  bool _acepto = false;
  bool _guardando = false;
  String? _error;

  Future<void> _aceptar() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .aceptarTerminos(uid, kVersionTerminos);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070F1F),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.privacy_tip_outlined,
                    color: Color(0xFF8FD7FF),
                    size: 44,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Antes de seguir',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Publicamos nuestra política de privacidad y los términos del '
                    'piloto. Explican qué datos usamos (ubicación, fotos, carnet '
                    'si te postulas) y con quién los compartimos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _acepto,
                        onChanged: (v) => setState(() => _acepto = v ?? false),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: TextoAceptoTerminos(),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFFF8A8A)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _acepto && !_guardando ? _aceptar : null,
                      child: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Aceptar y continuar'),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(authRepositoryProvider).cerrarSesion(),
                    child: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),
          ),
        ),
      ),
    );
  }
}

/// Bloque "Privacidad y cuenta" para los perfiles (cliente, empleado,
/// repartidor): ver los documentos y eliminar la cuenta.
class SeccionPrivacidadCuenta extends ConsumerWidget {
  const SeccionPrivacidadCuenta({super.key});

  Future<void> _eliminar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
          'Se borran tu perfil, tu ubicación de casa y tus solicitudes '
          '(incluidas las fotos del carnet y las selfies). No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).eliminarCuenta();
      messenger.showSnackBar(
        const SnackBar(content: Text('Tu cuenta fue eliminada.')),
      );
    } on EliminarCuentaException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar la cuenta. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Política de privacidad'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/legal/privacidad'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Términos y condiciones'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/legal/terminos'),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Colors.red.shade700,
            ),
            title: Text(
              'Eliminar mi cuenta',
              style: TextStyle(color: Colors.red.shade700),
            ),
            onTap: () => _eliminar(context, ref),
          ),
        ],
      ),
    );
  }
}
