import '../../shared/data/pedido_acciones.dart';
import '../../shared/models/app_user.dart';
import '../../shared/models/pedido.dart';

/// Etapas por las que pasa la ropa de un pedido "en proceso"; el panel 3D va
/// rotando al empleado por ellas (cada ~75 s) para que se vea el trabajo real.
const _etapasLavado = ['lavando', 'secando', 'prensa', 'planchando', 'vapor'];

int _hash(String s) => s.codeUnits.fold(7, (a, c) => (a * 31 + c) & 0x7fffffff);

/// Qué está haciendo cada empleado, deducido de los pedidos de la lavandería
/// (el empleado no tiene que avisar nada): si hay trabajo, trabaja; si no,
/// descansa. Si el propio empleado marcó una actividad hace menos de 10 min,
/// se respeta esa.
Map<String, String> actividadesAutomaticas(
  List<AppUser> equipo,
  List<Pedido> pedidos,
  DateTime ahora,
) {
  final tareas = <String>[];
  final tic = ahora.millisecondsSinceEpoch ~/ 75000;
  for (final p in pedidos.where((p) => p.estado == EstadoPedido.enProceso)) {
    tareas.add(_etapasLavado[(tic + _hash(p.id)) % _etapasLavado.length]);
  }
  final enCola = pedidos.where(
    (p) => p.estado == EstadoPedido.recibido && p.ropaRecibida,
  );
  if (enCola.isNotEmpty) tareas.add('colgando');
  final atencion = pedidos.any(
    (p) => p.estado == EstadoPedido.listo || esperaRopaDelCliente(p),
  );
  if (atencion) tareas.add('recepcion');

  final ordenados = [...equipo]..sort((a, b) => a.uid.compareTo(b.uid));
  final out = <String, String>{};
  var i = 0;
  for (final e in ordenados) {
    final reciente =
        e.actividadEn != null &&
        ahora.difference(e.actividadEn!).inMinutes < 10 &&
        e.actividad != 'descanso';
    if (reciente) {
      out[e.uid] = e.actividad;
    } else {
      out[e.uid] = i < tareas.length ? tareas[i++] : 'descanso';
    }
  }
  return out;
}
