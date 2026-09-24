import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:http/http.dart' as http;

import '../../core/errors/app_exceptions.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/product_repository.dart';
import '../http/api_client.dart';

/// [ProductRepository] contra RadarPrice API (FastAPI). Errores: ver [ApiClient].
class HttpProductRepository implements ProductRepository {
  HttpProductRepository({
    required String baseUrl,
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
    bool requireHttps = kReleaseMode,
  }) : _api = ApiClient(baseUrl: baseUrl, client: client, timeout: timeout, requireHttps: requireHttps);

  final ApiClient _api;

  /// Tamaño de página de `/products` (máximo del backend: 500).
  static const catalogPageSize = 200;

  /// Tope de seguridad ante un backend que no pagine bien (≈20 000 productos).
  static const _maxCatalogPages = 100;

  // ---------------------------------------------------------------------------
  // ProductRepository
  // ---------------------------------------------------------------------------

  /// Ranking global. El filtro/orden por talla lo aplica `HotDealsNotifier`.
  @override
  Future<List<Product>> getHotDeals() async {
    final json = await _getJson(_uri('products/deals'));
    return _parseList(json, Product.fromJson);
  }

  @override
  Future<List<Product>> getCatalog() async {
    final all = <Product>[];
    for (var page = 0; page < _maxCatalogPages; page++) {
      final json = await _getJson(_uri('products', {
        'limit': '$catalogPageSize',
        'offset': '${page * catalogPageSize}',
      }));
      final items = _parseList(json, Product.fromJson);
      all.addAll(items);
      if (items.length < catalogPageSize) return List.unmodifiable(all);
    }
    throw const UnexpectedResponseException('El catálogo supera el máximo de páginas admitido');
  }

  @override
  Future<List<Product>> searchProducts(String query, {String? size}) async {
    final q = query.trim();
    final json = await _getJson(_uri('products', {
      if (q.isNotEmpty) 'q': q,
      if (size != null && size.trim().isNotEmpty) 'size': size.trim(),
    }));
    return _parseList(json, Product.fromJson);
  }

  @override
  Future<Product> getProductBySku(String sku) async {
    final normalized = sku.trim();
    if (normalized.isEmpty) throw ProductNotFoundException(sku);
    final json = await _getJson(
      _uri('products/${Uri.encodeComponent(normalized)}'),
      notFoundSku: sku,
    );
    return _parseObject(json, Product.fromJson);
  }

  @override
  Future<List<PricePoint>> getPriceHistory(String sku, {int days = 90}) async {
    if (days <= 0) throw ArgumentError.value(days, 'days', 'Debe ser > 0');
    final normalized = sku.trim();
    if (normalized.isEmpty) throw ProductNotFoundException(sku);
    final json = await _getJson(
      _uri('products/${Uri.encodeComponent(normalized)}/history', {'days': '$days'}),
      notFoundSku: sku,
    );
    return _parseList(json, PricePoint.fromJson);
  }

  void dispose() => _api.dispose();

  Uri _uri(String path, [Map<String, String> query = const {}]) => _api.uri(path, query);

  Future<Object?> _getJson(Uri uri, {String? notFoundSku}) => _api.get(
        uri,
        mapError: (status, _) => status == 404 && notFoundSku != null ? ProductNotFoundException(notFoundSku) : null,
      );

  static List<T> _parseList<T>(Object? json, T Function(Map<String, dynamic>) fromJson) =>
      ApiClient.parseList(json, fromJson);

  static T _parseObject<T>(Object? json, T Function(Map<String, dynamic>) fromJson) =>
      ApiClient.parseObject(json, fromJson);
}
