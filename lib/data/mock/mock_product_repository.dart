import 'dart:math';

import '../../core/errors/app_exceptions.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/product_repository.dart';
import 'mock_catalog.dart';

/// Repositorio en memoria que simula latencia de red.
///
/// El histórico de precios es pseudoaleatorio pero determinista por SKU
/// (misma serie en cada llamada) y siempre termina en `lowestPrice`.
class MockProductRepository implements ProductRepository {
  MockProductRepository({
    List<Product>? catalog,
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? clock,
  })  : _catalog = List.unmodifiable(catalog ?? buildMockCatalog()),
        _clock = clock ?? DateTime.now;

  final List<Product> _catalog;
  final Duration latency;
  final DateTime Function() _clock;

  /// Horizonte fijo: garantiza que 30d sea un sufijo exacto de 90d.
  static const int _historyHorizonDays = 365;

  @override
  Future<List<Product>> getHotDeals() async {
    await _simulateNetwork();
    final ranked = [..._catalog]..sort((a, b) => b.savingsPercent.compareTo(a.savingsPercent));
    return List.unmodifiable(ranked);
  }

  @override
  Future<List<Product>> searchProducts(String query, {String? size}) async {
    await _simulateNetwork();
    final tokens = _normalize(query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final sizeFilter = size?.trim();

    return List.unmodifiable(_catalog.where((product) {
      final haystack = _normalize('${product.brand} ${product.model} ${product.sku}');
      final matchesText = tokens.every(haystack.contains);
      final matchesSize =
          sizeFilter == null || sizeFilter.isEmpty || product.isAvailableInSize(sizeFilter);
      return matchesText && matchesSize;
    }));
  }

  @override
  Future<Product> getProductBySku(String sku) async {
    await _simulateNetwork();
    return _findOrThrow(sku);
  }

  @override
  Future<List<PricePoint>> getPriceHistory(String sku, {int days = 90}) async {
    if (days <= 0) throw ArgumentError.value(days, 'days', 'Debe ser > 0');
    await _simulateNetwork();
    final product = _findOrThrow(sku);
    final full = _generateHistory(product, max(days, _historyHorizonDays));
    return List.unmodifiable(full.sublist(full.length - (days + 1)));
  }

  // ---------------------------------------------------------------------------

  Future<void> _simulateNetwork() => Future<void>.delayed(latency);

  Product _findOrThrow(String sku) {
    final normalized = sku.trim().toUpperCase();
    for (final product in _catalog) {
      if (product.sku.toUpperCase() == normalized) return product;
    }
    throw ProductNotFoundException(sku);
  }

  static String _normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'["()]'), ' ');

  /// Serie de [length] + 1 puntos diarios (fecha local, 00:00) acabando hoy.
  /// Tendencia desde ~100-120% de retail hasta lowestPrice, con ruido y
  /// shocks puntuales (restocks / flash sales) que se disipan.
  List<PricePoint> _generateHistory(Product product, int length) {
    final random = Random(_stableSeed(product.sku));
    final now = _clock();
    final end = product.lowestPrice;
    final start = product.retailPrice * (1.0 + random.nextDouble() * 0.2);
    final floor = end * 0.85;

    var shock = 0.0;
    return List.generate(length + 1, (i) {
      final t = i / length;
      final trend = start + (end - start) * t;
      if (random.nextDouble() < 0.06) {
        shock = (random.nextBool() ? -1 : 1) * end * (0.05 + random.nextDouble() * 0.10);
      }
      shock *= 0.8;
      final noise = (random.nextDouble() - 0.5) * end * 0.03;
      final price = i == length ? end : max(floor, trend + shock + noise);
      return PricePoint(
        // Constructor por componentes: evita desfases por cambio de horario (DST).
        date: DateTime(now.year, now.month, now.day - (length - i)),
        price: (price * 100).roundToDouble() / 100,
      );
    });
  }

  /// Hash estable entre ejecuciones (String.hashCode no lo garantiza).
  static int _stableSeed(String input) =>
      input.codeUnits.fold(17, (hash, unit) => (hash * 31 + unit) & 0x7fffffff);
}
