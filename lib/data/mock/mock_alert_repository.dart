import '../../core/errors/app_exceptions.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/alert_repository.dart';

/// Persistencia en memoria. Vive mientras viva su provider (no autoDispose).
class MockAlertRepository implements AlertRepository {
  MockAlertRepository({
    List<PriceAlert>? seed,
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? clock,
  }) : _store = {
          for (final alert in seed ?? _defaultSeed((clock ?? DateTime.now)())) alert.id: alert,
        };

  final Map<String, PriceAlert> _store;
  final Duration latency;

  @override
  Future<List<PriceAlert>> getAlerts() async {
    await _simulateNetwork();
    final sorted = _store.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  @override
  Future<void> toggleAlert(String alertId) async {
    await _simulateNetwork();
    final alert = _store[alertId];
    if (alert == null) throw AlertNotFoundException(alertId);
    _store[alertId] = alert.copyWith(isActive: !alert.isActive);
  }

  @override
  Future<void> createAlert(PriceAlert alert) async {
    if (alert.targetPrice <= 0) {
      throw ArgumentError.value(alert.targetPrice, 'targetPrice', 'Debe ser > 0');
    }
    await _simulateNetwork();
    if (_store.containsKey(alert.id)) throw AlertAlreadyExistsException(alert.id);
    _store[alert.id] = alert;
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
        ),
        PriceAlert(
          id: 'alert_seed_dunk',
          productId: 'prd_dd1391-100',
          sku: 'HF5441-100',
          targetPrice: 95,
          targetSize: '43',
          isActive: false,
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        PriceAlert(
          id: 'alert_seed_campus',
          productId: 'prd_hq8708',
          sku: 'HQ8708',
          targetPrice: 90,
          isActive: true,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];
}
