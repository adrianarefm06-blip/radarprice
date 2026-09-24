import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radarprice/application/providers/providers.dart';
import 'package:radarprice/core/errors/app_exceptions.dart';
import 'package:radarprice/data/mock/in_memory_favorites_repository.dart';
import 'package:radarprice/data/mock/mock_alert_repository.dart';
import 'package:radarprice/data/mock/mock_product_repository.dart';
import 'package:radarprice/domain/models/models.dart';
import 'package:radarprice/infrastructure/http/api_client.dart';
import 'package:radarprice/infrastructure/repositories/device_id_store.dart';
import 'package:radarprice/infrastructure/repositories/http_alert_repository.dart';
import 'package:radarprice/presentation/screens/alerts_screen.dart';
import 'package:radarprice/presentation/screens/product_detail_screen.dart';
import 'package:radarprice/presentation/widgets/create_alert_sheet.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _deviceId = '0123456789abcdef0123456789abcdef';

Map<String, Object?> _alertJson({String id = 'alt_1', bool triggered = false}) => {
      'id': id,
      'productId': 'prd_hq8708',
      'sku': 'HQ8708',
      'targetPrice': 80,
      'targetSize': '42',
      'isActive': true,
      'createdAt': '2026-09-24T10:00:00Z',
      'triggeredAt': triggered ? '2026-09-24T12:00:00Z' : null,
      'triggeredPrice': triggered ? 79.95 : null,
      'currentPrice': triggered ? 79.95 : 89.95,
    };

final _campus = Product.fromOffers(
  id: 'prd_hq8708',
  sku: 'HQ8708',
  brand: 'adidas',
  model: 'Campus 00s',
  imageUrl: 'https://cdn.test/hq8708.webp',
  retailPrice: 120,
  sizeOffers: {
    '42': [
      const StoreOffer(
        storeName: 'Zalando',
        storeLogoUrl: 'https://cdn.test/z.png',
        price: 100,
        inStock: true,
        affiliateUrl: 'https://z.test',
      ),
    ],
    '43': [
      const StoreOffer(
        storeName: 'Zalando',
        storeLogoUrl: 'https://cdn.test/z.png',
        price: 110,
        inStock: false,
        affiliateUrl: 'https://z.test',
      ),
    ],
  },
);

/// Repositorio que falla en las mutaciones (rollback optimista).
class _FailingAlerts extends MockAlertRepository {
  _FailingAlerts() : super(latency: Duration.zero);

  @override
  Future<PriceAlert> setActive(String alertId, {required bool isActive}) async =>
      throw const NetworkException();

  @override
  Future<void> deleteAlert(String alertId) async => throw const NetworkException();
}

Future<void> settle(WidgetTester tester) =>
    tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

void main() {
  test('PriceAlert.fromJson con estado del servidor', () {
    final idle = PriceAlert.fromJson(_alertJson());
    expect((idle.isTriggered, idle.currentPrice, idle.triggeredAt), (false, 89.95, null));
    final fired = PriceAlert.fromJson(_alertJson(triggered: true));
    expect((fired.isTriggered, fired.triggeredPrice), (true, 79.95));
    expect(PriceAlert.fromJson(fired.toJson()), fired);
    expect(fired.copyWith(isActive: false).isTriggered, isFalse);
  });

  group('HttpAlertRepository', () {
    late List<http.Request> requests;

    HttpAlertRepository repo(http.Response Function(http.Request) handler) {
      requests = [];
      final client = MockClient((request) async {
        requests.add(request);
        return handler(request);
      });
      return HttpAlertRepository(
        api: ApiClient(baseUrl: 'http://api.test', client: client, requireHttps: false),
        deviceId: () async => _deviceId,
      );
    }

    http.Response json(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

    test('envía X-Device-Id y el cuerpo esperado', () async {
      final alerts = repo((r) => r.method == 'GET' ? json([_alertJson()]) : json(_alertJson(), 201));

      expect((await alerts.getAlerts()).single.id, 'alt_1');
      await alerts.createAlert(sku: 'HQ8708', targetPrice: 80, targetSize: '42');
      await alerts.createAlert(sku: 'HQ8708', targetPrice: 80);

      expect(requests.map((r) => r.headers['X-Device-Id']).toSet(), {_deviceId});
      expect(requests[1].url.path, '/api/v1/alerts');
      expect(jsonDecode(requests[1].body), {'sku': 'HQ8708', 'targetPrice': 80, 'targetSize': '42'});
      expect(jsonDecode(requests[2].body), {'sku': 'HQ8708', 'targetPrice': 80});
    });

    test('PATCH / DELETE y mapeo de errores', () async {
      final alerts = repo((r) => switch ((r.method, r.url.path)) {
            ('PATCH', '/api/v1/alerts/alt_1') => json(_alertJson()),
            ('DELETE', '/api/v1/alerts/alt_1') => http.Response('', 204),
            ('POST', _) => json({'detail': 'Ya tienes una alerta para esta zapatilla y talla'}, 409),
            _ => json({'detail': 'Alerta no encontrada'}, 404),
          });

      expect((await alerts.setActive('alt_1', isActive: false)).id, 'alt_1');
      expect(jsonDecode(requests.last.body), {'isActive': false});
      await alerts.deleteAlert('alt_1');
      await expectLater(
        alerts.createAlert(sku: 'HQ8708', targetPrice: 80),
        throwsA(isA<AlertConflictException>().having((e) => e.message, 'message', contains('Ya tienes'))),
      );
      await expectLater(alerts.deleteAlert('alt_x'), throwsA(isA<AlertNotFoundException>()));
      expect(() => alerts.createAlert(sku: 'HQ8708', targetPrice: 0), throwsArgumentError);
    });
  });

  group('DeviceIdStore', () {
    setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

    test('genera 128 bits una vez y los persiste', () async {
      final store = DeviceIdStore(random: Random(1));
      final ids = await Future.wait([store.read(), store.read()]);
      expect(ids.toSet(), hasLength(1));
      expect(ids.first, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(await DeviceIdStore(random: Random(2)).read(), ids.first);
    });
  });

  group('AlertsNotifier', () {
    test('rollback de pausar y borrar si falla la red', () async {
      final container = ProviderContainer(overrides: [alertRepositoryProvider.overrideWithValue(_FailingAlerts())]);
      addTearDown(container.dispose);
      final before = await container.read(alertsProvider.future);
      final notifier = container.read(alertsProvider.notifier);

      await expectLater(notifier.setActive('alert_seed_j4', isActive: false), throwsA(isA<NetworkException>()));
      await expectLater(notifier.delete('alert_seed_j4'), throwsA(isA<NetworkException>()));
      expect(container.read(alertsProvider).requireValue, before);
      expect(container.read(triggeredAlertCountProvider), 1);
    });
  });

  group('UI', () {
    late MockAlertRepository alerts;

    Widget app(Widget home) => ProviderScope(
          overrides: [
            productRepositoryProvider.overrideWithValue(MockProductRepository(catalog: [_campus], latency: Duration.zero)),
            alertRepositoryProvider.overrideWithValue(alerts),
            favoritesRepositoryProvider.overrideWithValue(InMemoryFavoritesRepository()),
          ],
          child: MaterialApp(home: home),
        );

    setUp(() {
      GoogleFonts.config.allowRuntimeFetching = false;
      alerts = MockAlertRepository(seed: const [], latency: Duration.zero);
    });

    test('precio sugerido y parseo', () {
      expect(CreateAlertSheet.suggestedTarget(100, 120), 90);
      expect(CreateAlertSheet.suggestedTarget(null, 120), 108);
      expect(CreateAlertSheet.parsePrice('89,95'), 89.95);
      expect(CreateAlertSheet.parsePrice('abc'), isNull);
    });

    testWidgets('detalle → campana → crear alerta con las tallas reales', (tester) async {
      await tester.pumpWidget(app(ProductDetailScreen(sku: _campus.sku, initialProduct: _campus)));
      await settle(tester);

      await tester.tap(find.byTooltip('Crear alerta de precio'));
      await settle(tester);
      expect(find.text('Crear alerta de precio'), findsOneWidget);

      await tester.tap(find.text('Cualquier talla'));
      await settle(tester);
      expect(find.text('EU 43'), findsWidgets); // tallas del producto, no una lista fija
      await tester.tap(find.text('EU 42').last);
      await settle(tester);
      expect(find.text('Ahora desde 100 €'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('alert-target-price')), '0');
      await tester.tap(find.text('Crear alerta'));
      await settle(tester);
      expect(find.text('Introduce un precio válido'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('alert-target-price')), '85,50');
      await tester.tap(find.text('Crear alerta'));
      await settle(tester);

      final stored = (await tester.runAsync(alerts.getAlerts))!.single;
      expect((stored.sku, stored.targetSize, stored.targetPrice), ('HQ8708', '42', 85.5));
      expect(find.textContaining('Alerta creada'), findsOneWidget);
    });

    testWidgets('lista: deslizar borra la alerta', (tester) async {
      await tester.runAsync(() => alerts.createAlert(sku: 'HQ8708', targetPrice: 80, targetSize: '42'));
      await tester.pumpWidget(app(const Scaffold(body: AlertsScreen())));
      await tester.pumpAndSettle();
      expect(find.text('EU 42, por debajo de 80 €'), findsOneWidget);

      await tester.drag(find.text('adidas Campus 00s'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(await tester.runAsync(alerts.getAlerts), isEmpty);
      expect(find.text('Aún no tienes alertas'), findsOneWidget);
    });
  });
}
