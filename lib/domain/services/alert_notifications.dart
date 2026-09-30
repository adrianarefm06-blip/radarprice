import '../models/models.dart';
import '../repositories/alert_repository.dart';

/// Clave de un disparo concreto. Una alerta que se rearma (el precio volvió a subir)
/// y vuelve a cumplirse tiene otro `triggeredAt` → otro aviso.
String triggerKey(PriceAlert alert) => '${alert.id}@${alert.triggeredAt!.toUtc().toIso8601String()}';

/// Alertas disparadas (y activas) de las que aún no se ha avisado, más antiguas primero.
List<PriceAlert> pendingNotifications(Iterable<PriceAlert> alerts, Set<String> notified) =>
    alerts.where((a) => a.isTriggered && !notified.contains(triggerKey(a))).toList()
      ..sort((a, b) => a.triggeredAt!.compareTo(b.triggeredAt!));

/// Texto del aviso: "adidas Campus 00s talla 42: 72,00 € (objetivo 80,00 €)".
({String title, String body}) notificationText(PriceAlert alert) {
  String euros(double value) => '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  final size = alert.targetSize == null ? '' : ' talla ${alert.targetSize}';
  final price = alert.triggeredPrice ?? alert.currentPrice;
  return (
    title: '¡Ha bajado de precio!',
    body: '${alert.displayName}$size: ${price == null ? 'por debajo de tu objetivo' : euros(price)} '
        '(objetivo ${euros(alert.targetPrice)})',
  );
}

/// Registro persistente de los disparos ya notificados.
abstract interface class NotifiedAlertsStore {
  Future<Set<String>> load();
  Future<void> save(Set<String> keys);
}

/// Consulta las alertas y avisa de las disparadas nuevas. Devuelve cuántas se notificaron.
/// Usada en primer plano (al abrir/volver a la app) y en segundo plano (WorkManager).
/// Si [notify] falla en una, las siguientes no se marcan (se reintentará en la próxima comprobación).
Future<int> checkTriggeredAlerts({
  required AlertRepository alerts,
  required NotifiedAlertsStore store,
  required Future<void> Function(PriceAlert alert) notify,
}) async {
  final current = await alerts.getAlerts();
  final notified = await store.load();
  var sent = 0;
  try {
    for (final alert in pendingNotifications(current, notified)) {
      await notify(alert);
      notified.add(triggerKey(alert));
      sent++;
    }
  } finally {
    // Solo se conservan claves de alertas que siguen existiendo (el registro no crece sin fin).
    final ids = {for (final a in current) a.id};
    await store.save({for (final key in notified) if (ids.contains(key.split('@').first)) key});
  }
  return sent;
}
