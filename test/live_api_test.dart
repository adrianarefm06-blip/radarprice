// Contrato contra el backend desplegado: la app parsea las respuestas reales de producción.
// Se omite salvo que se indique la URL (lo hace el workflow "APK de prueba"):
//   flutter test test/live_api_test.dart --dart-define=LIVE_API_BASE_URL=https://radarprice-api.onrender.com
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:radarprice/infrastructure/http/api_client.dart';
import 'package:radarprice/infrastructure/repositories/http_alert_repository.dart';
import 'package:radarprice/infrastructure/repositories/http_product_repository.dart';

const _baseUrl = String.fromEnvironment('LIVE_API_BASE_URL');
const _timeout = Duration(seconds: 90); // arranque en frío del plan gratuito de Render

void main() {
  final skip = _baseUrl.isEmpty ? 'define LIVE_API_BASE_URL para probar contra el backend real' : null;

  group('API en producción', skip: skip, () {
    // Perezoso: con la URL vacía (test omitido) el constructor lanzaría al cargar el fichero.
    late final products = HttpProductRepository(baseUrl: _baseUrl, timeout: _timeout, requireHttps: true);

    test('catálogo, detalle e historial se parsean', () async {
      final catalog = await products.getCatalog();
      expect(catalog, isNotEmpty);

      final offers = [for (final p in catalog) for (final list in p.sizeOffers.values) ...list];
      final live = offers.where((o) => !o.isSimulated).toList();
      // Informe visible en el log del workflow.
      // ignore: avoid_print
      print('productos=${catalog.length} ofertas=${offers.length} reales=${live.length} '
          'tiendas reales=${live.map((o) => o.storeName).toSet()}');
      expect(live, isNotEmpty, reason: 'el sync debería haber traído precios reales');

      final sku = catalog.first.sku;
      expect((await products.getProductBySku(sku)).sku, sku);
      await products.getPriceHistory(sku, days: 30);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('alertas: crear, listar y borrar con un dispositivo efímero', () async {
      final api = ApiClient(baseUrl: _baseUrl, timeout: _timeout, requireHttps: true);
      final device = 'ci-${Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0')}-live-test';
      final alerts = HttpAlertRepository(api: api, deviceId: () async => device);
      final sku = (await products.getCatalog()).first.sku;

      final created = await alerts.createAlert(sku: sku, targetPrice: 1);
      try {
        expect((await alerts.getAlerts()).map((a) => a.id), [created.id]);
      } finally {
        await alerts.deleteAlert(created.id);
      }
      expect(await alerts.getAlerts(), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
