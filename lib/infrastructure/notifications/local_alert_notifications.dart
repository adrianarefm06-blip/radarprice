import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/models.dart';
import '../../domain/services/alert_notifications.dart';

/// Notificaciones locales de alertas (sin servidor de push: la app consulta la API).
/// Tocar el aviso abre el detalle de la zapatilla (payload = SKU).
class LocalAlertNotifications {
  LocalAlertNotifications._();

  static final instance = LocalAlertNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'price_alerts',
      'Alertas de precio',
      channelDescription: 'Aviso cuando una zapatilla baja de tu precio objetivo',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Idempotente. [onOpenSku]: el usuario tocó un aviso con la app abierta o en segundo plano.
  Future<void> init({void Function(String sku)? onOpenSku}) async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) {
        final sku = response.payload;
        if (sku != null && sku.isNotEmpty) onOpenSku?.call(sku);
      },
    );
    _ready = true;
  }

  /// SKU del aviso que abrió la app desde cerrada, si lo hubo.
  Future<String?> launchSku() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final sku = details.notificationResponse?.payload;
    return sku == null || sku.isEmpty ? null : sku;
  }

  /// Android 13+: diálogo de permiso (solo la primera vez). true = concedido.
  Future<bool> requestPermission() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission() ??
      false;

  Future<void> show(PriceAlert alert) {
    final text = notificationText(alert);
    return _plugin.show(
      id: alert.id.hashCode & 0x7fffffff,
      title: text.title,
      body: text.body,
      notificationDetails: _details,
      payload: alert.sku,
    );
  }
}
