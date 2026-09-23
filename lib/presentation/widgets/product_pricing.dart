import 'package:flutter/foundation.dart' show immutable;

import '../../domain/models/models.dart';

/// View-model de precio para una talla (o para "todas" si [selectedSize] es null).
@immutable
class ProductPricing {
  const ProductPricing._({
    required this.retailPrice,
    required this.price,
    required this.savingsPercent,
    required this.bestOffer,
    required this.offerSize,
    required this.selectedSize,
  });

  factory ProductPricing.of(Product product, String? selectedSize) {
    if (selectedSize != null) {
      final offer = product.bestOfferForSize(selectedSize);
      return ProductPricing._(
        retailPrice: product.retailPrice,
        price: offer?.price,
        savingsPercent: product.savingsPercentForSize(selectedSize),
        bestOffer: offer,
        offerSize: selectedSize,
        selectedSize: selectedSize,
      );
    }

    StoreOffer? best;
    String? bestSize;
    final sizes = product.sizeOffers.keys.toList()..sort(Product.compareSizes);
    for (final size in sizes) {
      final offer = product.bestOfferForSize(size);
      if (offer != null && (best == null || offer.price < best.price)) {
        best = offer;
        bestSize = size;
      }
    }
    return ProductPricing._(
      retailPrice: product.retailPrice,
      price: best?.price,
      savingsPercent: best == null ? null : product.savingsPercent,
      bestOffer: best,
      offerSize: bestSize,
      selectedSize: null,
    );
  }

  final double retailPrice;
  final double? price;
  final double? savingsPercent;
  final StoreOffer? bestOffer;
  final String? offerSize;
  final String? selectedSize;

  bool get isAvailable => price != null;
  bool get isDeal => (savingsPercent ?? 0) >= 1;
  bool get isAboveRetail => (savingsPercent ?? 0) <= -1;
  bool get showsRetailReference => price != null && price != retailPrice;
}
