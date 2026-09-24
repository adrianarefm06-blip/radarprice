import '../models/models.dart';

/// Alertas del dispositivo. Errores: [AppException] (`AlertNotFoundException`,
/// `AlertConflictException` si está duplicada o se alcanzó el límite, red…).
abstract interface class AlertRepository {
  /// Alertas del dispositivo, más recientes primero.
  Future<List<PriceAlert>> getAlerts();

  /// Crea una alerta activa. El servidor asigna el id y la evalúa al momento.
  /// Lanza `ArgumentError` si [targetPrice] <= 0.
  Future<PriceAlert> createAlert({required String sku, required double targetPrice, String? targetSize});

  /// Pausa o reactiva. Devuelve el estado reevaluado por el servidor.
  Future<PriceAlert> setActive(String alertId, {required bool isActive});

  Future<void> deleteAlert(String alertId);
}
