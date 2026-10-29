import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/shared/models/pedido.dart';
import '../../firebase_options.dart';
import 'notification_service.dart';

const _servicioId = 'lavanderia_servicio';
const _notificacionForegroundId = 888;

/// Configura (pero no arranca) el servicio en primer plano. Se llama una sola
/// vez al iniciar la app. Solo tiene sentido en Android/iOS, nunca en Web.
Future<void> configurarServicioSegundoPlano() async {
  if (kIsWeb) return;

  try {
    // Android exige que el canal exista ANTES de que el servicio llame a
    // startForeground() con ese id, o el sistema mata la app entera con
    // CannotPostForegroundServiceNotificationException ("Bad notification").
    const canalServicio = AndroidNotificationChannel(
      _servicioId,
      'Servicio de Lavandería App',
      description: 'Mantiene activas las notificaciones de tus pedidos',
      importance: Importance.low,
    );
    await NotificationService.instance.crearCanal(canalServicio);

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _servicioId,
        initialNotificationTitle: 'Lavandería App',
        initialNotificationContent: 'Recibiendo notificaciones de tus pedidos',
        foregroundServiceNotificationId: _notificacionForegroundId,
      ),
      iosConfiguration: IosConfiguration(onForeground: _onStart),
    );
  } catch (e) {
    debugPrint(
      'No se pudo configurar el servicio de notificaciones en segundo plano: $e',
    );
  }
}

/// Las notificaciones en segundo plano son una mejora, nunca algo de lo que
/// dependa el resto de la app: si Android rechaza arrancar el foreground
/// service (pasa en algunos dispositivos/emuladores por sus restricciones de
/// "background start"), esto NO debe tumbar la app — solo se pierde el aviso.
Future<void> iniciarServicioSegundoPlano() async {
  if (kIsWeb) return;
  final service = FlutterBackgroundService();
  try {
    final yaCorriendo = await service.isRunning();
    if (!yaCorriendo) await service.startService();
    return;
  } catch (e) {
    debugPrint(
      'No se pudo iniciar el servicio en segundo plano, reintentando: $e',
    );
  }
  // Android a veces rechaza el arranque justo después de un cambio de sesión
  // (restricción de "background start"); un reintento corto suele alcanzar.
  await Future.delayed(const Duration(seconds: 2));
  try {
    if (!await service.isRunning()) await service.startService();
  } catch (e) {
    debugPrint(
      'No se pudo iniciar el servicio de notificaciones en segundo plano: $e',
    );
  }
}

Future<void> detenerServicioSegundoPlano() async {
  if (kIsWeb) return;
  try {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) service.invoke('stopService');
  } catch (e) {
    debugPrint(
      'No se pudo detener el servicio de notificaciones en segundo plano: $e',
    );
  }
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.inicializar();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final user = auth.currentUser;
  if (user == null) {
    service.stopSelf();
    return;
  }

  final usuarioDoc = await firestore.collection('usuarios').doc(user.uid).get();
  final role = usuarioDoc.data()?['role'] as String? ?? 'cliente';

  switch (role) {
    case 'cliente':
      _escucharPedidosCliente(firestore, user.uid);
      break;
    case 'empleado':
    case 'admin':
      final lavanderiaId = usuarioDoc.data()?['lavanderiaId'] as String?;
      if (lavanderiaId != null) {
        _escucharPedidosLavanderia(firestore, lavanderiaId);
      } else {
        service.stopSelf();
      }
      break;
    case 'repartidor':
      _escucharPedidosDisponibles(firestore);
      break;
    default:
      // verificador / superadmin no necesitan este servicio
      service.stopSelf();
  }
}

void _escucharPedidosCliente(FirebaseFirestore firestore, String uid) {
  final estadosPrevios = <String, EstadoPedido>{};
  var primerSnapshot = true;

  firestore
      .collection('pedidos')
      .where('clienteId', isEqualTo: uid)
      .snapshots()
      .listen((snap) {
        for (final doc in snap.docs) {
          final estadoNuevo = estadoPedidoFromString(
            doc.data()['estado'] as String? ?? 'recibido',
          );
          final estadoAnterior = estadosPrevios[doc.id];
          if (!primerSnapshot &&
              estadoAnterior != null &&
              estadoAnterior != estadoNuevo) {
            final nombre =
                doc.data()['lavanderiaNombre'] as String? ?? 'Tu pedido';
            NotificationService.instance.mostrar(
              id: doc.id.hashCode,
              titulo: nombre,
              cuerpo: 'Tu pedido ahora está: ${estadoNuevo.label}',
            );
          }
          estadosPrevios[doc.id] = estadoNuevo;
        }
        primerSnapshot = false;
      });
}

void _escucharPedidosLavanderia(
  FirebaseFirestore firestore,
  String lavanderiaId,
) {
  final idsPrevios = <String>{};
  var primerSnapshot = true;

  firestore
      .collection('pedidos')
      .where('lavanderiaId', isEqualTo: lavanderiaId)
      .snapshots()
      .listen((snap) {
        for (final doc in snap.docs) {
          if (!primerSnapshot && !idsPrevios.contains(doc.id)) {
            NotificationService.instance.mostrar(
              id: doc.id.hashCode,
              titulo: 'Nuevo pedido',
              cuerpo: 'Llegó un pedido nuevo a tu lavandería.',
            );
          }
          idsPrevios.add(doc.id);
        }
        primerSnapshot = false;
      });
}

void _escucharPedidosDisponibles(FirebaseFirestore firestore) {
  final idsPrevios = <String>{};
  var primerSnapshot = true;

  firestore
      .collection('pedidos')
      .where('tipoEntrega', isEqualTo: 'recojoDomicilio')
      .where('repartidorUid', isNull: true)
      .snapshots()
      .listen((snap) {
        for (final doc in snap.docs) {
          if (!primerSnapshot && !idsPrevios.contains(doc.id)) {
            final nombre =
                doc.data()['lavanderiaNombre'] as String? ?? 'una lavandería';
            NotificationService.instance.mostrar(
              id: doc.id.hashCode,
              titulo: 'Nuevo encargo disponible',
              cuerpo: 'Hay un pedido para repartir desde $nombre.',
            );
          }
          idsPrevios.add(doc.id);
        }
        primerSnapshot = false;
      });
}
