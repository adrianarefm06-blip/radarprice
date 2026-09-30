import 'package:flutter_test/flutter_test.dart';
import 'package:radarprice/domain/models/models.dart';
import 'package:radarprice/domain/repositories/alert_repository.dart';
import 'package:radarprice/domain/services/alert_notifications.dart';

PriceAlert _alert(
  String id, {
  DateTime? triggeredAt,
  bool active = true,
  String? size = '42',
  String? name = 'Campus 00s',
}) =>
    PriceAlert(
      id: id,
      productId: 'prd_hq8708',
      sku: 'HQ8708',
      targetPrice: 80,
      targetSize: size,
      isActive: active,
      createdAt: DateTime.utc(2026, 9, 1),
      triggeredAt: triggeredAt,
      triggeredPrice: triggeredAt == null ? null : 72,
      brand: name == null ? null : 'adidas',
      productName: name,
    );

class _Alerts implements AlertRepository {
  _Alerts(this.alerts);

  List<PriceAlert> alerts;

  @override
  Future<List<PriceAlert>> getAlerts() async => alerts;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Store implements NotifiedAlertsStore {
  Set<String> keys = {};

  @override
  Future<Set<String>> load() async => {...keys};

  @override
  Future<void> save(Set<String> value) async => keys = {...value};
}

void main() {
  final t1 = DateTime.utc(2026, 9, 30, 12);
  final t2 = DateTime.utc(2026, 10, 1, 6);

  test('solo avisa de disparos activos y nuevos, más antiguos primero', () {
    final pending = pendingNotifications([
      _alert('a', triggeredAt: t2),
      _alert('b', triggeredAt: t1),
      _alert('c'), // sin disparar
      _alert('d', triggeredAt: t1, active: false), // pausada
    ], {});
    expect(pending.map((a) => a.id), ['b', 'a']);
    expect(pendingNotifications([_alert('a', triggeredAt: t1)], {triggerKey(_alert('a', triggeredAt: t1))}), isEmpty);
  });

  test('texto con nombre, talla y precios en formato español', () {
    final text = notificationText(_alert('a', triggeredAt: t1));
    expect(text.title, '¡Ha bajado de precio!');
    expect(text.body, 'adidas Campus 00s talla 42: 72,00 € (objetivo 80,00 €)');
    expect(notificationText(_alert('a', triggeredAt: t1, size: null, name: null)).body,
        'HQ8708: 72,00 € (objetivo 80,00 €)');
  });

  test('checkTriggeredAlerts: avisa una vez, de nuevo si se rearma y limpia claves viejas', () async {
    final repo = _Alerts([_alert('a', triggeredAt: t1), _alert('b')]);
    final store = _Store();
    final sent = <String>[];
    Future<void> notify(PriceAlert alert) async => sent.add(alert.id);

    expect(await checkTriggeredAlerts(alerts: repo, store: store, notify: notify), 1);
    expect(await checkTriggeredAlerts(alerts: repo, store: store, notify: notify), 0); // ya avisada

    repo.alerts = [_alert('a', triggeredAt: t2)]; // rearmada y disparada otra vez; 'b' borrada
    expect(await checkTriggeredAlerts(alerts: repo, store: store, notify: notify), 1);
    expect(sent, ['a', 'a']);

    repo.alerts = [];
    await checkTriggeredAlerts(alerts: repo, store: store, notify: notify);
    expect(store.keys, isEmpty);
  });

  test('si falla un aviso no se marca (se reintentará)', () async {
    final repo = _Alerts([_alert('a', triggeredAt: t1), _alert('b', triggeredAt: t2)]);
    final store = _Store();
    Future<void> notify(PriceAlert alert) async {
      if (alert.id == 'b') throw StateError('sin permiso');
    }

    await expectLater(checkTriggeredAlerts(alerts: repo, store: store, notify: notify), throwsStateError);
    expect(store.keys, {triggerKey(_alert('a', triggeredAt: t1))});
  });

  test('PriceAlert: brand y productName opcionales en JSON', () {
    final json = _alert('a', triggeredAt: t1).toJson();
    expect(PriceAlert.fromJson(json), _alert('a', triggeredAt: t1));
    expect(PriceAlert.fromJson({...json}..remove('brand')..remove('productName')).displayName, 'HQ8708');
  });
}
