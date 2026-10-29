import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificaciones locales (no FCM): las dispara el propio dispositivo cuando
/// detecta un cambio relevante en Firestore, sin backend ni Cloud Functions.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inicializado = false;

  static const canalPedidos = AndroidNotificationChannel(
    'lavanderia_pedidos',
    'Notificaciones de pedidos',
    description:
        'Avisa cuando cambia el estado de un pedido o aparece uno nuevo',
    importance: Importance.high,
  );

  Future<void> inicializar() async {
    if (_inicializado) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(canalPedidos);

    _inicializado = true;
  }

  /// Pide el permiso de notificaciones (Android 13+). Solo debe llamarse
  /// desde el isolate principal con una Activity visible — el servicio en
  /// segundo plano no tiene pantalla y esta llamada revienta con un
  /// NullPointerException ahí (Context.checkPermission sobre null).
  Future<void> pedirPermiso() async {
    await inicializar();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Crea un canal adicional (por ejemplo el que usa el foreground service).
  /// El plugin debe estar inicializado antes de poder resolver la
  /// implementación específica de Android.
  Future<void> crearCanal(AndroidNotificationChannel canal) async {
    await inicializar();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(canal);
  }

  Future<void> mostrar({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    await inicializar();
    await _plugin.show(
      id,
      titulo,
      cuerpo,
      NotificationDetails(
        android: AndroidNotificationDetails(
          canalPedidos.id,
          canalPedidos.name,
          channelDescription: canalPedidos.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
