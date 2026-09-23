/// Jerarquía cerrada de errores de dominio. La UI puede hacer `switch` exhaustivo.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class ProductNotFoundException extends AppException {
  const ProductNotFoundException(this.sku) : super('Producto no encontrado: $sku');

  final String sku;
}

final class AlertNotFoundException extends AppException {
  const AlertNotFoundException(this.alertId) : super('Alerta no encontrada: $alertId');

  final String alertId;
}

final class AlertAlreadyExistsException extends AppException {
  const AlertAlreadyExistsException(this.alertId) : super('La alerta ya existe: $alertId');

  final String alertId;
}

/// Lanzada cuando una petición se descarta (p. ej. búsqueda superada por otra
/// más reciente durante el debounce). Nunca debería llegar a mostrarse en UI.
final class RequestCancelledException extends AppException {
  const RequestCancelledException() : super('Petición cancelada');
}
