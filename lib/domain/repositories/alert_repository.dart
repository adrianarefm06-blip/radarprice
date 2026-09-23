import '../models/models.dart';

abstract interface class AlertRepository {
  /// Alertas del usuario, más recientes primero.
  Future<List<PriceAlert>> getAlerts();

  /// Activa/pausa. Lanza `AlertNotFoundException` si no existe.
  Future<void> toggleAlert(String alertId);

  /// Lanza `AlertAlreadyExistsException` si el id está duplicado y
  /// `ArgumentError` si [PriceAlert.targetPrice] <= 0.
  Future<void> createAlert(PriceAlert alert);
}
