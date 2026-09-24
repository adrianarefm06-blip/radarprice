import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radarprice/infrastructure/repositories/http_product_repository.dart';

Map<String, Object?> _productJson(int i) => {
      'id': 'prd_$i',
      'sku': 'SKU-${i.toString().padLeft(4, '0')}',
      'brand': 'Nike',
      'model': 'Modelo $i',
      'imageUrl': 'https://cdn.test/$i.webp',
      'lowestPrice': 90,
      'retailPrice': 100,
      'sizeOffers': <String, Object?>{},
    };

void main() {
  test('getCatalog recorre todas las páginas de /products (sin truncar a 20)', () async {
    const total = HttpProductRepository.catalogPageSize + 37;
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      final limit = int.parse(request.url.queryParameters['limit']!);
      final offset = int.parse(request.url.queryParameters['offset']!);
      final page = [for (var i = offset; i < total && i < offset + limit; i++) _productJson(i)];
      return http.Response(jsonEncode(page), 200, headers: {'content-type': 'application/json'});
    });
    final repository = HttpProductRepository(baseUrl: 'http://api.test', client: client, requireHttps: false);

    final catalog = await repository.getCatalog();

    expect(catalog, hasLength(total));
    expect(catalog.map((p) => p.sku).toSet(), hasLength(total));
    expect(requests.map((u) => u.path).toSet(), {'/api/v1/products'});
    expect(requests.map((u) => u.queryParameters['offset']), ['0', '${HttpProductRepository.catalogPageSize}']);
  });

  test('release exige HTTPS', () {
    expect(() => HttpProductRepository(baseUrl: 'http://10.0.2.2:8000', requireHttps: true), throwsArgumentError);
    expect(HttpProductRepository(baseUrl: 'https://api.radarprice.app', requireHttps: true), isNotNull);
    expect(HttpProductRepository(baseUrl: 'http://10.0.2.2:8000', requireHttps: false), isNotNull);
  });
}
