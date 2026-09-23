/// Jerarquía cerrada de errores de dominio. La UI puede hacer `switch` exhaustivo.
/// [message] es apto para mostrarse al usuario.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  /// Si la política de retry de Riverpod debe reintentar.
  bool get isRetryable => false;

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

// -----------------------------------------------------------------------------
// Red / API
// -----------------------------------------------------------------------------

final class NetworkException extends AppException {
  const NetworkException({this.cause})
      : super('No hay conexión con el servidor. Comprueba tu red e inténtalo de nuevo.');

  /// Detalle técnico para logs (no se muestra al usuario).
  final String? cause;

  @override
  bool get isRetryable => true;
}

final class RequestTimeoutException extends AppException {
  const RequestTimeoutException() : super('El servidor tarda demasiado en responder.');

  @override
  bool get isRetryable => true;
}

final class ServerException extends AppException {
  const ServerException(this.statusCode, {this.detail}) : super('Error del servidor ($statusCode).');

  final int statusCode;
  final String? detail;

  @override
  bool get isRetryable => statusCode >= 500 || statusCode == 429;
}

final class InvalidRequestException extends AppException {
  const InvalidRequestException(super.message);
}

final class UnexpectedResponseException extends AppException {
  const UnexpectedResponseException(this.reason) : super('Respuesta inesperada del servidor.');

  /// Detalle técnico para logs.
  final String reason;
}
