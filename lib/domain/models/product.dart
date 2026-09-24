import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'product_gender.dart';
import 'store_offer.dart';

/// Zapatilla del catálogo con sus ofertas agrupadas por talla EU.
///
/// - Precios en EUR.
/// - [sizeOffers] se congela (inmutable en profundidad) al construir.
/// - [lowestPrice] = oferta en stock más barata de cualquier talla.
///   Si modificas [sizeOffers] vía [copyWith], recalcula con [computeLowestPrice].
@immutable
class Product {
  Product({
    required this.id,
    required this.sku,
    required this.brand,
    required this.model,
    required this.imageUrl,
    required this.lowestPrice,
    required this.retailPrice,
    required Map<String, List<StoreOffer>> sizeOffers,
    this.colorway,
    this.gender = ProductGender.unisex,
  }) : sizeOffers = _freeze(sizeOffers);

  /// Construye calculando [lowestPrice] desde las ofertas en stock.
  /// Sin stock en ninguna talla → usa [retailPrice] como referencia.
  factory Product.fromOffers({
    required String id,
    required String sku,
    required String brand,
    required String model,
    required String imageUrl,
    required double retailPrice,
    required Map<String, List<StoreOffer>> sizeOffers,
    String? colorway,
    ProductGender gender = ProductGender.unisex,
  }) =>
      Product(
        id: id,
        sku: sku,
        brand: brand,
        model: model,
        imageUrl: imageUrl,
        lowestPrice: computeLowestPrice(sizeOffers) ?? retailPrice,
        retailPrice: retailPrice,
        sizeOffers: sizeOffers,
        colorway: colorway,
        gender: gender,
      );

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawOffers = json['sizeOffers'] as Map<String, dynamic>;
    return Product(
      id: json['id'] as String,
      sku: json['sku'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      imageUrl: json['imageUrl'] as String,
      lowestPrice: (json['lowestPrice'] as num).toDouble(),
      retailPrice: (json['retailPrice'] as num).toDouble(),
      colorway: json['colorway'] as String?,
      gender: ProductGender.fromApi(json['gender']),
      sizeOffers: {
        for (final MapEntry(key: size, value: offers) in rawOffers.entries)
          size: [
            for (final offer in offers as List<dynamic>)
              StoreOffer.fromJson(offer as Map<String, dynamic>),
          ],
      },
    );
  }

  final String id;
  final String sku;
  final String brand;
  final String model;
  final String imageUrl;
  final double lowestPrice;
  final double retailPrice;
  final Map<String, List<StoreOffer>> sizeOffers;

  /// Colores oficiales, p. ej. "White/Black". `null` si la API no lo informa.
  final String? colorway;
  final ProductGender gender;

  static const _deepEquality = DeepCollectionEquality();

  // ---------------------------------------------------------------------------
  // Helpers de consulta (pensados para la UI)
  // ---------------------------------------------------------------------------

  String get displayName => '$brand $model';

  /// Tallas con al menos una oferta en stock, ordenadas numéricamente.
  List<String> get availableSizes =>
      List.unmodifiable(sizeOffers.keys.where(isAvailableInSize).toList()..sort(compareSizes));

  bool isAvailableInSize(String size) => sizeOffers[size]?.any((o) => o.inStock) ?? false;

  /// Ofertas de la talla: primero en stock, después por precio ascendente.
  List<StoreOffer> offersForSize(String size) =>
      List.unmodifiable(<StoreOffer>[...?sizeOffers[size]]..sort(_byStockThenPrice));

  /// Oferta en stock más barata para la talla, o `null` si no hay stock.
  StoreOffer? bestOfferForSize(String size) {
    StoreOffer? best;
    for (final offer in sizeOffers[size] ?? const <StoreOffer>[]) {
      if (offer.inStock && (best == null || offer.price < best.price)) best = offer;
    }
    return best;
  }

  double? lowestPriceForSize(String size) => bestOfferForSize(size)?.price;

  /// % de ahorro frente a retail. Negativo = se vende por encima de retail (reventa).
  double get savingsPercent => _savingsFor(lowestPrice);

  double? savingsPercentForSize(String size) {
    final price = lowestPriceForSize(size);
    return price == null ? null : _savingsFor(price);
  }

  double _savingsFor(double price) =>
      retailPrice <= 0 ? 0 : (retailPrice - price) / retailPrice * 100;

  // ---------------------------------------------------------------------------
  // Utilidades estáticas
  // ---------------------------------------------------------------------------

  static double? computeLowestPrice(Map<String, List<StoreOffer>> sizeOffers) {
    double? lowest;
    for (final offers in sizeOffers.values) {
      for (final offer in offers) {
        if (offer.inStock && (lowest == null || offer.price < lowest)) lowest = offer.price;
      }
    }
    return lowest;
  }

  /// Orden numérico de tallas: '42' < '42.5' < '43'. Fallback alfabético.
  static int compareSizes(String a, String b) {
    final da = double.tryParse(a.replaceAll(',', '.'));
    final db = double.tryParse(b.replaceAll(',', '.'));
    if (da != null && db != null) return da.compareTo(db);
    return a.compareTo(b);
  }

  static int _byStockThenPrice(StoreOffer a, StoreOffer b) {
    if (a.inStock != b.inStock) return a.inStock ? -1 : 1;
    return a.price.compareTo(b.price);
  }

  static Map<String, List<StoreOffer>> _freeze(Map<String, List<StoreOffer>> source) =>
      Map<String, List<StoreOffer>>.unmodifiable({
        for (final MapEntry(key: size, value: offers) in source.entries)
          size: List<StoreOffer>.unmodifiable(offers),
      });

  // ---------------------------------------------------------------------------
  // Inmutabilidad y serialización
  // ---------------------------------------------------------------------------

  Product copyWith({
    String? id,
    String? sku,
    String? brand,
    String? model,
    String? imageUrl,
    double? lowestPrice,
    double? retailPrice,
    Map<String, List<StoreOffer>>? sizeOffers,
    String? colorway,
    ProductGender? gender,
  }) =>
      Product(
        id: id ?? this.id,
        sku: sku ?? this.sku,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        imageUrl: imageUrl ?? this.imageUrl,
        lowestPrice: lowestPrice ?? this.lowestPrice,
        retailPrice: retailPrice ?? this.retailPrice,
        sizeOffers: sizeOffers ?? this.sizeOffers,
        colorway: colorway ?? this.colorway,
        gender: gender ?? this.gender,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'brand': brand,
        'model': model,
        'imageUrl': imageUrl,
        'lowestPrice': lowestPrice,
        'retailPrice': retailPrice,
        'colorway': colorway,
        'gender': gender.apiValue,
        'sizeOffers': {
          for (final MapEntry(key: size, value: offers) in sizeOffers.entries)
            size: [for (final offer in offers) offer.toJson()],
        },
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          other.id == id &&
          other.sku == sku &&
          other.brand == brand &&
          other.model == model &&
          other.imageUrl == imageUrl &&
          other.lowestPrice == lowestPrice &&
          other.retailPrice == retailPrice &&
          other.colorway == colorway &&
          other.gender == gender &&
          _deepEquality.equals(other.sizeOffers, sizeOffers);

  @override
  int get hashCode => Object.hash(
        id,
        sku,
        brand,
        model,
        imageUrl,
        lowestPrice,
        retailPrice,
        colorway,
        gender,
        _deepEquality.hash(sizeOffers),
      );

  @override
  String toString() => 'Product($sku, $displayName, lowest: €$lowestPrice, retail: €$retailPrice)';
}
