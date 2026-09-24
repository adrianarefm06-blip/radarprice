import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radarprice/application/providers/providers.dart';
import 'package:radarprice/core/errors/app_exceptions.dart';
import 'package:radarprice/data/mock/mock_alert_repository.dart';
import 'package:radarprice/data/mock/mock_product_repository.dart';
import 'package:radarprice/domain/models/models.dart';

void main() {
  late MockProductRepository products;
  late MockAlertRepository alerts;

  setUp(() {
    products = MockProductRepository(latency: Duration.zero);
    alerts = MockAlertRepository(latency: Duration.zero);
  });

  group('MockProductRepository', () {
    test('catálogo: 3 productos, ≥3 tiendas por talla, lowestPrice coherente', () async {
      final deals = await products.getHotDeals();
      expect(deals, hasLength(3));
      for (final p in deals) {
        for (final offers in p.sizeOffers.values) {
          expect(offers.map((o) => o.storeName).toSet().length, greaterThanOrEqualTo(3));
        }
        expect(p.lowestPrice, Product.computeLowestPrice(p.sizeOffers));
      }
    });

    test('hot deals ordenados por ahorro', () async {
      final deals = await products.getHotDeals();
      expect(deals.map((p) => p.sku), ['HQ8708', 'HF5441-100', 'DH6927-111']);
    });

    test('búsqueda por texto y talla', () async {
      expect((await products.searchProducts('panda')).single.sku, 'HF5441-100');
      expect((await products.searchProducts('jordan military')).single.sku, 'DH6927-111');
      expect(await products.searchProducts(''), hasLength(3));
      expect(await products.searchProducts('yeezy'), isEmpty);
    });

    test('SKU inexistente lanza ProductNotFoundException', () {
      expect(products.getProductBySku('XXX'), throwsA(isA<ProductNotFoundException>()));
    });

    test('histórico: días+1 puntos, termina en lowestPrice, determinista', () async {
      final product = await products.getProductBySku('HQ8708');
      final h90 = await products.getPriceHistory('HQ8708');
      final h30 = await products.getPriceHistory('HQ8708', days: 30);
      expect(h90, hasLength(91));
      expect(h90.last.price, product.lowestPrice);
      expect(h30, h90.sublist(60));
      expect(products.getPriceHistory('HQ8708', days: 0), throwsArgumentError);
    });
  });

  group('MockAlertRepository', () {
    test('toggle y create persisten en memoria', () async {
      await alerts.toggleAlert('alert_seed_j4');
      final toggled = (await alerts.getAlerts()).firstWhere((a) => a.id == 'alert_seed_j4');
      expect(toggled.isActive, isFalse);

      final draft = PriceAlert.draft(productId: 'prd_hq8708', sku: 'HQ8708', targetPrice: 85);
      await alerts.createAlert(draft);
      expect((await alerts.getAlerts()).first, draft);
      expect(alerts.createAlert(draft), throwsA(isA<AlertAlreadyExistsException>()));
      expect(alerts.toggleAlert('nope'), throwsA(isA<AlertNotFoundException>()));
    });
  });

  group('Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: [
        productRepositoryProvider.overrideWithValue(products),
        alertRepositoryProvider.overrideWithValue(alerts),
      ]);
      addTearDown(container.dispose);
    });

    test('hotDeals reacciona a la talla seleccionada', () async {
      container.read(selectedSizeFilterProvider.notifier).select('43');
      final deals = await container.read(hotDealsProvider.future);
      expect(deals.every((p) => p.isAvailableInSize('43')), isTrue);
      expect(deals.first.sku, 'HQ8708');
    });

    test('productSearchProvider con debounce', () async {
      const params = (query: 'dunk', size: '44');
      container.listen(productSearchProvider(params), (_, __) {});
      final results = await container.read(productSearchProvider(params).future);
      expect(results.single.sku, 'HF5441-100');
    });

    test('alertsProvider toggle optimista', () async {
      await container.read(alertsProvider.future);
      await container.read(alertsProvider.notifier).toggle('alert_seed_dunk');
      final dunk = container.read(alertsProvider).requireValue.firstWhere((a) => a.id == 'alert_seed_dunk');
      expect(dunk.isActive, isTrue);
    });
  });
}
