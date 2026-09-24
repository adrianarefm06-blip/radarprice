import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:http/http.dart' as http;

import '../../core/errors/app_exceptions.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/product_repository.dart';

/// [ProductRepository] contra RadarPrice API (FastAPI).
///
/// Errores → jerarquía [AppException]:
///   timeout            → RequestTimeoutException      (reintentable)
///   sin red / socket   → NetworkException             (reintentable)
///   404 en /{sku}      → ProductNotFoundException
///   400 / 422          → InvalidRequestException
///   5xx / 429 / otros  → ServerException              (reintentable si 5xx/429)
///   JSON / tipos       → UnexpectedResponseException
class HttpProductRepository implements ProductRepository {
  HttpProductRepository({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
    bool requireHttps = kReleaseMode,
  })  : _baseUri = _normalizeBase(baseUrl, requireHttps: requireHttps),
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  final Uri _baseUri;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  static const _apiPrefix = 'api/v1';
  static const _headers = {'Accept': 'application/json'};

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

  /// Cierra el cliente HTTP solo si lo creó este repositorio.
  void dispose() {
    if (_ownsClient) _client.close();
  }

  // ---------------------------------------------------------------------------
  // HTTP
  // ---------------------------------------------------------------------------

  static Uri _normalizeBase(String baseUrl, {required bool requireHttps}) {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Se requiere una URL absoluta');
    }
    // Release: nunca tráfico en claro. Define --dart-define=API_BASE_URL=https://…
    if (requireHttps && uri.scheme != 'https') {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'En release la API debe servirse por HTTPS');
    }
    return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
  }

  Uri _uri(String path, [Map<String, String> query = const {}]) {
    final uri = _baseUri.resolve('$_apiPrefix/$path');
    return query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  Future<Object?> _getJson(Uri uri, {String? notFoundSku}) async {
    final http.Response response;
    try {
      response = await _client.get(uri, headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw const RequestTimeoutException();
    } on http.ClientException catch (e) {
      throw NetworkException(cause: e.message);
    } on Exception catch (e) {
      // SocketException / HandshakeException no envueltas por el cliente.
      throw NetworkException(cause: e.toString());
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException catch (e) {
        throw UnexpectedResponseException('JSON inválido: ${e.message}');
      }
    }

    final detail = _extractDetail(response);
    throw switch (status) {
      404 when notFoundSku != null => ProductNotFoundException(notFoundSku),
      400 || 422 => InvalidRequestException(detail ?? 'Petición no válida'),
      _ => ServerException(status, detail: detail),
    };
  }

  /// FastAPI: `{"detail": "texto"}` o `{"detail": [{"msg": "..."}]}` (422).
  static String? _extractDetail(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) return null;
      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) return first['msg'] as String;
      }
    } on FormatException {
      // Cuerpo no JSON (proxy, HTML de error): sin detalle.
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  static List<T> _parseList<T>(Object? json, T Function(Map<String, dynamic>) fromJson) {
    if (json is! List) throw const UnexpectedResponseException('Se esperaba una lista');
    return _guardParse(() => List<T>.unmodifiable([
          for (final item in json) fromJson(item as Map<String, dynamic>),
        ]));
  }

  static T _parseObject<T>(Object? json, T Function(Map<String, dynamic>) fromJson) {
    if (json is! Map<String, dynamic>) throw const UnexpectedResponseException('Se esperaba un objeto');
    return _guardParse(() => fromJson(json));
  }

  static T _guardParse<T>(T Function() parse) {
    try {
      return parse();
      // ignore: avoid_catching_errors
    } on TypeError catch (e) {
      throw UnexpectedResponseException('Tipos no esperados: $e');
    } on FormatException catch (e) {
      throw UnexpectedResponseException('Formato no válido: ${e.message}');
    }
  }
}
