import 'package:flutter/foundation.dart' show immutable;

import '../models/models.dart';

/// Segmento del feed de chollos. [all] no filtra.
/// Hombre y Mujer incluyen los modelos unisex (se venden en ambos tallajes).
enum DealSegment {
  all(label: 'Todos'),
  men(label: 'Hombre'),
  women(label: 'Mujer'),
  unisex(label: 'Unisex');

  const DealSegment({required this.label});

  final String label;

  bool includes(ProductGender gender) => switch (this) {
        DealSegment.all => true,
        DealSegment.men => gender != ProductGender.women,
        DealSegment.women => gender != ProductGender.men,
        DealSegment.unisex => gender == ProductGender.unisex,
      };
}

/// Precio de una tienda dentro del comparador de una tarjeta.
@immutable
class StoreQuote {
  const StoreQuote({
    required this.storeName,
    required this.storeLogoUrl,
    this.offer,
    this.size,
    this.isCheapest = false,
  });

  final String storeName;
  final String storeLogoUrl;

  /// Oferta en stock más barata (en la talla pedida o en cualquiera). `null` = sin stock.
  final StoreOffer? offer;

  /// Talla de [offer]. Útil en modo "Todas" para indicar dónde está el precio.
  final String? size;

  /// Precio mínimo entre todas las tiendas (empates: todas marcadas).
  final bool isCheapest;

  bool get inStock => offer != null;
  double? get price => offer?.price;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreQuote &&
          other.storeName == storeName &&
          other.storeLogoUrl == storeLogoUrl &&
          other.offer == offer &&
          other.size == size &&
          other.isCheapest == isCheapest;

  @override
  int get hashCode => Object.hash(storeName, storeLogoUrl, offer, size, isCheapest);
}

/// Zapatilla en el feed consolidado: mejor descuento + comparador por tienda.
@immutable
class DealComparison {
  const DealComparison({
    required this.product,
    required this.size,
    required this.bestPrice,
    required this.maxSavingsPercent,
    required this.quotes,
  });

  final Product product;

  /// Talla del filtro; `null` = todas.
  final String? size;
  final double bestPrice;

  /// % de ahorro de [bestPrice] frente a retail. Negativo = por encima de retail.
  final double maxSavingsPercent;

  /// En stock por precio ascendente; después las tiendas sin stock (alfabético).
  final List<StoreQuote> quotes;

  int get inStockCount => quotes.where((q) => q.inStock).length;
}

/// `null` si ninguna tienda tiene stock (en [size], si se indica).
DealComparison? buildDealComparison(Product product, {String? size}) {
  final logos = <String, String>{};
  final best = <String, (StoreOffer, String)>{};

  final sizes = size == null ? product.sizeOffers.keys : [size];
  for (final offer in product.sizeOffers.values.expand((offers) => offers)) {
    logos.putIfAbsent(offer.storeName, () => offer.storeLogoUrl);
  }
  for (final s in sizes) {
    for (final offer in product.sizeOffers[s] ?? const <StoreOffer>[]) {
      if (!offer.inStock) continue;
      final current = best[offer.storeName];
      if (current == null || offer.price < current.$1.price) best[offer.storeName] = (offer, s);
    }
  }
  if (best.isEmpty) return null;

  final bestPrice = best.values.map((e) => e.$1.price).reduce((a, b) => a < b ? a : b);
  final quotes = [
    for (final MapEntry(key: store, value: logo) in logos.entries)
      StoreQuote(
        storeName: store,
        storeLogoUrl: logo,
        offer: best[store]?.$1,
        size: best[store]?.$2,
        isCheapest: best[store]?.$1.price == bestPrice,
      ),
  ]..sort(_byStockPriceName);

  return DealComparison(
    product: product,
    size: size,
    bestPrice: bestPrice,
    maxSavingsPercent: product.retailPrice <= 0 ? 0 : (product.retailPrice - bestPrice) / product.retailPrice * 100,
    quotes: List.unmodifiable(quotes),
  );
}

/// Feed global: segmento → stock en la talla → mayor descuento primero.
List<DealComparison> buildDealComparisons(
  Iterable<Product> products, {
  String? size,
  DealSegment segment = DealSegment.all,
}) {
  final deals = [
    for (final product in products)
      if (segment.includes(product.gender)) ?buildDealComparison(product, size: size),
  ]..sort(_byDiscount);
  return List.unmodifiable(deals);
}

/// Tallas con stock en alguna tienda para los productos del segmento.
List<String> availableDealSizes(Iterable<Product> products, {DealSegment segment = DealSegment.all}) {
  final sizes = <String>{
    for (final product in products)
      if (segment.includes(product.gender)) ...product.availableSizes,
  };
  return List.unmodifiable(sizes.toList()..sort(Product.compareSizes));
}

int _byStockPriceName(StoreQuote a, StoreQuote b) {
  if (a.inStock != b.inStock) return a.inStock ? -1 : 1;
  final byPrice = (a.price ?? 0).compareTo(b.price ?? 0);
  return byPrice != 0 ? byPrice : a.storeName.compareTo(b.storeName);
}

// -----------------------------------------------------------------------------
// Búsqueda y ordenación (en memoria, sin red)
// -----------------------------------------------------------------------------

enum DealSort {
  discount(label: 'Mayor descuento (%)'),
  price(label: 'Precio más bajo'),
  name(label: 'Nombre (A-Z)');

  const DealSort({required this.label});

  final String label;
}

/// Todas las palabras de [query] deben aparecer en marca, modelo, colorway o SKU.
/// Sin distinguir mayúsculas ni tildes; el SKU también casa sin guiones.
bool matchesDealQuery(Product product, String query) {
  final tokens = normalizeSearchText(query).split(RegExp(r'[\s"]+')).where((t) => t.isNotEmpty);
  if (tokens.isEmpty) return true;
  final haystack = normalizeSearchText(
    '${product.brand} ${product.model} ${product.colorway ?? ''} ${product.sku} ${product.sku.replaceAll('-', '')}',
  );
  return tokens.every(haystack.contains);
}

const _accents = {'á': 'a', 'à': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ë': 'e', 'í': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', 'ç': 'c'};

String normalizeSearchText(String value) {
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

/// Aplica texto, lista de SKUs permitidos (p. ej. favoritos) y orden. No muta [deals].
List<DealComparison> refineDeals(
  Iterable<DealComparison> deals, {
  String query = '',
  Set<String>? onlySkus,
  DealSort sort = DealSort.discount,
}) {
  final result = [
    for (final deal in deals)
      if ((onlySkus == null || onlySkus.contains(deal.product.sku)) && matchesDealQuery(deal.product, query)) deal,
  ]..sort(switch (sort) {
      DealSort.discount => _byDiscount,
      DealSort.price => _byPrice,
      DealSort.name => _byName,
    });
  return List.unmodifiable(result);
}

int _byDiscount(DealComparison a, DealComparison b) {
  final bySavings = b.maxSavingsPercent.compareTo(a.maxSavingsPercent);
  return bySavings != 0 ? bySavings : a.bestPrice.compareTo(b.bestPrice);
}

int _byPrice(DealComparison a, DealComparison b) {
  final byPrice = a.bestPrice.compareTo(b.bestPrice);
  return byPrice != 0 ? byPrice : b.maxSavingsPercent.compareTo(a.maxSavingsPercent);
}

int _byName(DealComparison a, DealComparison b) {
  final byName = normalizeSearchText(a.product.displayName).compareTo(normalizeSearchText(b.product.displayName));
  return byName != 0 ? byName : a.product.sku.compareTo(b.product.sku);
}
