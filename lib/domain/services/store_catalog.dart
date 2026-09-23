import 'package:flutter/foundation.dart' show immutable;

import '../models/models.dart';

/// Resumen de una tienda para el grid de Chollos.
@immutable
class StoreSummary {
  const StoreSummary({
    required this.storeName,
    required this.storeLogoUrl,
    required this.activeOfferCount,
    required this.productCount,
    this.bestSavingsPercent,
  });

  final String storeName;
  final String storeLogoUrl;

  /// Ofertas en stock (producto × talla).
  final int activeOfferCount;

  /// Productos distintos con al menos una talla en stock.
  final int productCount;

  /// Mayor % de ahorro vs retail entre ofertas en stock. `null` = sin stock.
  final double? bestSavingsPercent;

  bool get hasDeal => (bestSavingsPercent ?? 0) >= 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreSummary &&
          other.storeName == storeName &&
          other.storeLogoUrl == storeLogoUrl &&
          other.activeOfferCount == activeOfferCount &&
          other.productCount == productCount &&
          other.bestSavingsPercent == bestSavingsPercent;

  @override
  int get hashCode => Object.hash(storeName, storeLogoUrl, activeOfferCount, productCount, bestSavingsPercent);
}

/// Producto en el feed de una tienda.
@immutable
class StoreDealItem {
  const StoreDealItem({required this.product, required this.storeView});

  /// Producto completo (todas las tiendas) → pantalla de detalle.
  final Product product;

  /// Mismo producto con solo las ofertas de la tienda → tarjeta del feed.
  final Product storeView;
}

class _StoreAccumulator {
  _StoreAccumulator(this.logoUrl);

  final String logoUrl;
  final Set<String> skus = {};
  int activeOffers = 0;
  double? best;
}

List<StoreSummary> buildStoreSummaries(Iterable<Product> products) {
  final byStore = <String, _StoreAccumulator>{};
  for (final product in products) {
    for (final offers in product.sizeOffers.values) {
      for (final offer in offers) {
        final acc = byStore.putIfAbsent(offer.storeName, () => _StoreAccumulator(offer.storeLogoUrl));
        if (!offer.inStock) continue;
        acc
          ..activeOffers += 1
          ..skus.add(product.sku);
        if (product.retailPrice > 0) {
          final savings = (product.retailPrice - offer.price) / product.retailPrice * 100;
          final best = acc.best;
          if (best == null || savings > best) acc.best = savings;
        }
      }
    }
  }

  final summaries = [
    for (final MapEntry(key: name, value: acc) in byStore.entries)
      StoreSummary(
        storeName: name,
        storeLogoUrl: acc.logoUrl,
        activeOfferCount: acc.activeOffers,
        productCount: acc.skus.length,
        bestSavingsPercent: acc.best,
      ),
  ]..sort(_byActivityThenBestDeal);
  return List.unmodifiable(summaries);
}

int _byActivityThenBestDeal(StoreSummary a, StoreSummary b) {
  final activity = (b.activeOfferCount > 0 ? 1 : 0).compareTo(a.activeOfferCount > 0 ? 1 : 0);
  if (activity != 0) return activity;
  final deal = (b.bestSavingsPercent ?? double.negativeInfinity)
      .compareTo(a.bestSavingsPercent ?? double.negativeInfinity);
  return deal != 0 ? deal : a.storeName.compareTo(b.storeName);
}

/// Proyección del producto a una sola tienda (lowestPrice recalculado).
/// `null` si la tienda no lista el producto.
Product? productForStore(Product product, String storeName) {
  final scoped = <String, List<StoreOffer>>{};
  for (final MapEntry(key: size, value: offers) in product.sizeOffers.entries) {
    final storeOffers = [for (final offer in offers) if (offer.storeName == storeName) offer];
    if (storeOffers.isNotEmpty) scoped[size] = storeOffers;
  }
  if (scoped.isEmpty) return null;
  return Product.fromOffers(
    id: product.id,
    sku: product.sku,
    brand: product.brand,
    model: product.model,
    imageUrl: product.imageUrl,
    retailPrice: product.retailPrice,
    sizeOffers: scoped,
  );
}

/// Feed de la tienda: solo productos en stock (en [size] si se indica),
/// ordenados por ahorro en esa tienda.
List<StoreDealItem> buildStoreDeals(Iterable<Product> products, String storeName, {String? size}) {
  final items = <StoreDealItem>[];
  for (final product in products) {
    final view = productForStore(product, storeName);
    if (view == null) continue;
    final available = size == null ? view.availableSizes.isNotEmpty : view.isAvailableInSize(size);
    if (available) items.add(StoreDealItem(product: product, storeView: view));
  }

  double score(StoreDealItem item) =>
      (size == null ? item.storeView.savingsPercent : item.storeView.savingsPercentForSize(size)) ??
      double.negativeInfinity;

  items.sort((a, b) => score(b).compareTo(score(a)));
  return List.unmodifiable(items);
}

/// Tallas con stock en la tienda, ordenadas numéricamente.
List<String> availableSizesForStore(Iterable<Product> products, String storeName) {
  final sizes = <String>{
    for (final product in products)
      for (final MapEntry(key: size, value: offers) in product.sizeOffers.entries)
        if (offers.any((o) => o.storeName == storeName && o.inStock)) size,
  };
  return List.unmodifiable(sizes.toList()..sort(Product.compareSizes));
}
