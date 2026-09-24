import '../../core/errors/app_exceptions.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/alert_repository.dart';
import '../http/api_client.dart';

/// [AlertRepository] contra `/api/v1/alerts`, identificando el dispositivo con `X-Device-Id`.
class HttpAlertRepository implements AlertRepository {
  HttpAlertRepository({required this._api, required this._deviceId});

  final ApiClient _api;
  final Future<String> Function() _deviceId;

  @override
  Future<List<PriceAlert>> getAlerts() async =>
      ApiClient.parseList(await _send('GET', 'alerts'), PriceAlert.fromJson);

  @override
  Future<PriceAlert> createAlert({required String sku, required double targetPrice, String? targetSize}) async {
    if (targetPrice <= 0) throw ArgumentError.value(targetPrice, 'targetPrice', 'Debe ser > 0');
    final json = await _send('POST', 'alerts', body: {
      'sku': sku,
      'targetPrice': targetPrice,
      'targetSize': ?targetSize,
    });
    return ApiClient.parseObject(json, PriceAlert.fromJson);
  }

  @override
  Future<PriceAlert> setActive(String alertId, {required bool isActive}) async {
    final json = await _send('PATCH', 'alerts/${Uri.encodeComponent(alertId)}',
        body: {'isActive': isActive}, alertId: alertId);
    return ApiClient.parseObject(json, PriceAlert.fromJson);
  }

  @override
  Future<void> deleteAlert(String alertId) =>
      _send('DELETE', 'alerts/${Uri.encodeComponent(alertId)}', alertId: alertId);

  Future<Object?> _send(String method, String path, {Object? body, String? alertId}) async => _api.send(
        method,
        _api.uri(path),
        body: body,
        headers: {'X-Device-Id': await _deviceId()},
        mapError: (status, detail) => switch (status) {
          404 when alertId != null => AlertNotFoundException(alertId),
          404 => const InvalidRequestException('Esta zapatilla ya no está en el catálogo.'),
          409 => AlertConflictException(detail ?? 'Ya tienes una alerta igual.'),
          _ => null,
        },
      );
}
