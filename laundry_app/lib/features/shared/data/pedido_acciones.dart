import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../client/data/pedido_repository.dart';
import 'precio_pedido.dart';
import '../models/app_user.dart';
import '../models/lavanderia.dart';
import '../models/pedido.dart';

/// Actividad que se le asigna al empleado cuando avanza un pedido, para que
/// la ciudad 3D del admin muestre lo que de verdad está haciendo.
String? actividadPorEstado(EstadoPedido nuevo) => switch (nuevo) {
  EstadoPedido.enProceso => 'lavando',
  EstadoPedido.listo => 'recepcion',
  EstadoPedido.entregado => 'recepcion',
  EstadoPedido.recibido => null,
};

Future<void> _actividad(WidgetRef ref, String? actividad) async {
  final u = ref.read(currentAppUserProvider).valueOrNull;
  if (actividad == null || u == null || u.role != UserRole.empleado) return;
  try {
    await ref.read(authRepositoryProvider).cambiarActividad(u.uid, actividad);
  } catch (_) {
    // la actividad es decorativa: si falla, el pedido igual avanzó
  }
}

Future<void> avanzarPedido(WidgetRef ref, Pedido p, EstadoPedido nuevo) async {
  await ref
      .read(pedidoRepositoryProvider)
      .actualizarEstado(
        p.id,
        nuevo,
        costoPrendasConfirmado: await _precioDeLaLavanderia(ref, p, nuevo),
      );
  await _actividad(ref, actividadPorEstado(nuevo));
}

/// Al empezar a lavar, la lavandería recalcula el costo de las prendas con
/// SU lista de precios: el monto que mandó el celular del cliente se podía
/// manipular. Solo una vez por pedido.
Future<double?> _precioDeLaLavanderia(
  WidgetRef ref,
  Pedido p,
  EstadoPedido nuevo,
) async {
  if (p.precioConfirmado || nuevo != EstadoPedido.enProceso) return null;
  final doc = await ref
      .read(firestoreProvider)
      .collection('lavanderias')
      .doc(p.lavanderiaId)
      .get();
  if (!doc.exists) return null;
  final lav = Lavanderia.fromMap(doc.id, doc.data()!);
  return costoPrendasPara(
    lav,
    p.prendas,
    p.modoRopaRegular,
    p.cantidadRopaRegular,
  );
}

/// El cliente dejó su ropa en el mostrador: en la ciudad 3D se ve a quien la
/// registró recibiéndola y colgándola, y después vuelve a lo que estaba
/// haciendo (por eso aquí no se cambia su actividad).
Future<void> recibirRopa(WidgetRef ref, Pedido p) async {
  await ref.read(pedidoRepositoryProvider).marcarRopaRecibida(p.id);
}

/// Pedido de "yo llevo mis prendas" que todavía no llega al mostrador.
bool esperaRopaDelCliente(Pedido p) =>
    !p.necesitaRepartidor &&
    p.estado == EstadoPedido.recibido &&
    p.ropaRecibidaEn == null;
