import '../../core/errors/app_exceptions.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/alert_repository.dart';

/// Repositorio en memoria para tests y previews. Imita las reglas del servidor:
/// una alerta por zapatilla y talla, ids asignados aquí.
class MockAlertRepository implements AlertRepository {
  MockAlertRepository({
    List<PriceAlert>? seed,
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        _store = {
          for (final alert in seed ?? _defaultSeed((clock ?? DateTime.now)())) alert.id: alert,
        };

  final Map<String, PriceAlert> _store;
  final Duration latency;
  final DateTime Function() _clock;
  int _nextId = 0;

  @override
  Future<List<PriceAlert>> getAlerts() async {
    await _simulateNetwork();
    final sorted = _store.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  @override
  Future<PriceAlert> createAlert({required String sku, required double targetPrice, String? targetSize}) async {
    if (targetPrice <= 0) throw ArgumentError.value(targetPrice, 'targetPrice', 'Debe ser > 0');
    await _simulateNetwork();
    if (_store.values.any((a) => a.sku == sku && a.targetSize == targetSize)) {
      throw const AlertConflictException('Ya tienes una alerta para esta zapatilla y talla');
    }
    final alert = PriceAlert(
      id: 'alt_mock_${_nextId++}',
      productId: 'prd_${sku.toLowerCase()}',
      sku: sku,
      targetPrice: targetPrice,
      targetSize: targetSize,
      isActive: true,
      createdAt: _clock(),
    );
    return _store[alert.id] = alert;
  }

  @override
  Future<PriceAlert> setActive(String alertId, {required bool isActive}) async {
    await _simulateNetwork();
    final alert = _store[alertId];
    if (alert == null) throw AlertNotFoundException(alertId);
    return _store[alertId] = alert.copyWith(isActive: isActive);
  }

  @override
  Future<void> deleteAlert(String alertId) async {
    await _simulateNetwork();
    if (_store.remove(alertId) == null) throw AlertNotFoundException(alertId);
  }

  Future<void> _simulateNetwork() => Future<void>.delayed(latency);

  /// 3 estados de demo: activa sin disparar, pausada y activa ya disparada.
  static List<PriceAlert> _defaultSeed(DateTime now) => [
        PriceAlert(
          id: 'alert_seed_j4',
          productId: 'prd_dh6927-111',
          sku: 'DH6927-111',
          targetPrice: 200,
          targetSize: '42.5',
          isActive: true,
          createdAt: now.subtract(const Duration(days: 6)),
          currentPrice: 231,
        ),
        PriceAlert(
          id: 'alert_seed_dunk',
          productId: 'prd_hf5441-100',
          sku: 'HF5441-100',
          targetPrice: 95,
          targetSize: '43',
          isActive: false,
          createdAt: now.subtract(const Duration(days: 3)),
          currentPrice: 99,
        ),
        PriceAlert(
          id: 'alert_seed_campus',
          productId: 'prd_hq8708',
          sku: 'HQ8708',
          targetPrice: 90,
          isActive: true,
          createdAt: now.subtract(const Duration(days: 1)),
          triggeredAt: now.subtract(const Duration(hours: 5)),
          triggeredPrice: 89.95,
          currentPrice: 89.95,
        ),
      ];
}
