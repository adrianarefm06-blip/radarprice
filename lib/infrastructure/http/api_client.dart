import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:http/http.dart' as http;

import '../../core/errors/app_exceptions.dart';

/// Traduce un error HTTP a una excepción de dominio concreta del endpoint.
/// Devolver `null` aplica el mapeo por defecto.
typedef ApiErrorMapper = AppException? Function(int status, String? detail);

/// Cliente JSON de RadarPrice API. Errores → jerarquía [AppException]:
///   timeout            → RequestTimeoutException      (reintentable)
///   sin red / socket   → NetworkException             (reintentable)
///   400 / 422          → InvalidRequestException (con el detalle de FastAPI)
///   5xx / 429 / otros  → ServerException              (reintentable si 5xx/429)
///   JSON / tipos       → UnexpectedResponseException
class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
    bool requireHttps = kReleaseMode,
  })  : _baseUri = _normalizeBase(baseUrl, requireHttps: requireHttps),
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  static const _apiPrefix = 'api/v1';

  final Uri _baseUri;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  Uri uri(String path, [Map<String, String> query = const {}]) {
    final uri = _baseUri.resolve('$_apiPrefix/$path');
    return query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  /// Cuerpo JSON decodificado (`null` en 204).
  Future<Object?> send(
    String method,
    Uri uri, {
    Object? body,
    Map<String, String> headers = const {},
    ApiErrorMapper? mapError,
  }) async {
    final request = http.Request(method, uri)
      ..headers.addAll({'Accept': 'application/json', ...headers});
    if (body != null) {
      request
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(timeout));
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
      if (response.bodyBytes.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException catch (e) {
        throw UnexpectedResponseException('JSON inválido: ${e.message}');
      }
    }

    final detail = _extractDetail(response);
    throw mapError?.call(status, detail) ??
        switch (status) {
          400 || 422 => InvalidRequestException(detail ?? 'Petición no válida'),
          _ => ServerException(status, detail: detail),
        };
  }

  Future<Object?> get(Uri uri, {Map<String, String> headers = const {}, ApiErrorMapper? mapError}) =>
      send('GET', uri, headers: headers, mapError: mapError);

  /// Cierra el cliente HTTP solo si lo creó esta instancia.
  void dispose() {
    if (_ownsClient) _client.close();
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  static List<T> parseList<T>(Object? json, T Function(Map<String, dynamic>) fromJson) {
    if (json is! List) throw const UnexpectedResponseException('Se esperaba una lista');
    return guardParse(() => List<T>.unmodifiable([
          for (final item in json) fromJson(item as Map<String, dynamic>),
        ]));
  }

  static T parseObject<T>(Object? json, T Function(Map<String, dynamic>) fromJson) {
    if (json is! Map<String, dynamic>) throw const UnexpectedResponseException('Se esperaba un objeto');
    return guardParse(() => fromJson(json));
  }

  static T guardParse<T>(T Function() parse) {
    try {
      return parse();
      // ignore: avoid_catching_errors
    } on TypeError catch (e) {
      throw UnexpectedResponseException('Tipos no esperados: $e');
    } on FormatException catch (e) {
      throw UnexpectedResponseException('Formato no válido: ${e.message}');
    }
  }

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
}
