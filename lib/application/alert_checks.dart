import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../domain/services/alert_notifications.dart';
import '../infrastructure/http/api_client.dart';
import '../infrastructure/notifications/local_alert_notifications.dart';
import '../infrastructure/notifications/shared_prefs_notified_alerts_store.dart';
import '../infrastructure/repositories/device_id_store.dart';
import '../infrastructure/repositories/http_alert_repository.dart';
import 'providers/repository_providers.dart';

/// Comprobación periódica de alertas en segundo plano (Android WorkManager, ~cada hora;
/// el backend sincroniza precios cada 6 h). También se ejecuta al abrir o volver a la app.
const alertCheckTask = 'radarprice.alert-check';

/// Solo Android (el proyecto no tiene iOS). En tests y web no hace nada.
bool get alertNotificationsSupported => !kIsWeb && Platform.isAndroid;

/// Consulta la API y notifica las alertas disparadas nuevas. Independiente de Riverpod:
/// se usa también desde el isolate de segundo plano.
Future<int> runAlertCheck() async {
  if (!alertNotificationsSupported) return 0;
  final api = ApiClient(baseUrl: kApiBaseUrl, timeout: kApiTimeout);
  try {
    await LocalAlertNotifications.instance.init();
    return await checkTriggeredAlerts(
      alerts: HttpAlertRepository(api: api, deviceId: DeviceIdStore().read),
      store: SharedPrefsNotifiedAlertsStore(),
      notify: LocalAlertNotifications.instance.show,
    );
  } finally {
    api.dispose();
  }
}

@pragma('vm:entry-point')
void alertCheckDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await runAlertCheck();
    } catch (error) {
      // Sin red o servidor dormido: se reintentará en la próxima ejecución periódica.
      debugPrint('alert-check: $error');
    }
    return true;
  });
}

/// Pide permiso de notificaciones (Android 13+) la primera vez que el usuario crea una alerta.
Future<bool> requestAlertNotificationPermission() async {
  if (!alertNotificationsSupported) return false;
  await LocalAlertNotifications.instance.init();
  return LocalAlertNotifications.instance.requestPermission();
}

/// Registra la tarea periódica (se conserva si ya existía).
Future<void> scheduleAlertChecks() async {
  if (!alertNotificationsSupported) return;
  await Workmanager().initialize(alertCheckDispatcher);
  await Workmanager().registerPeriodicTask(
    alertCheckTask,
    alertCheckTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
