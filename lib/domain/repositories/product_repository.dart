import '../models/models.dart';

/// Contrato de catálogo. Las implementaciones lanzan [AppException] ante
/// errores de dominio (p. ej. `ProductNotFoundException`).
abstract interface class ProductRepository {
  /// Feed principal, ordenado por mayor ahorro frente a retail.
  Future<List<Product>> getHotDeals();

  /// Búsqueda por marca/modelo/SKU. Query vacía = catálogo completo.
  /// Con [size], solo productos con stock en esa talla.
  Future<List<Product>> searchProducts(String query, {String? size});

  /// Lanza `ProductNotFoundException` si el SKU no existe.
  Future<Product> getProductBySku(String sku);

  /// [days] + 1 puntos diarios, del más antiguo a hoy. [days] debe ser > 0.
  Future<List<PricePoint>> getPriceHistory(String sku, {int days = 90});
}
