import 'package:flutter/foundation.dart' show immutable;

/// Oferta de una tienda concreta para una talla concreta. Precio en EUR.
@immutable
class StoreOffer {
  const StoreOffer({
    required this.storeName,
    required this.storeLogoUrl,
    required this.price,
    required this.inStock,
    required this.affiliateUrl,
  });

  factory StoreOffer.fromJson(Map<String, dynamic> json) => StoreOffer(
        storeName: json['storeName'] as String,
        storeLogoUrl: json['storeLogoUrl'] as String,
        price: (json['price'] as num).toDouble(),
        inStock: json['inStock'] as bool,
        affiliateUrl: json['affiliateUrl'] as String,
      );

  final String storeName;
  final String storeLogoUrl;
  final double price;
  final bool inStock;
  final String affiliateUrl;

  StoreOffer copyWith({
    String? storeName,
    String? storeLogoUrl,
    double? price,
    bool? inStock,
    String? affiliateUrl,
  }) =>
      StoreOffer(
        storeName: storeName ?? this.storeName,
        storeLogoUrl: storeLogoUrl ?? this.storeLogoUrl,
        price: price ?? this.price,
        inStock: inStock ?? this.inStock,
        affiliateUrl: affiliateUrl ?? this.affiliateUrl,
      );

  Map<String, dynamic> toJson() => {
        'storeName': storeName,
        'storeLogoUrl': storeLogoUrl,
        'price': price,
        'inStock': inStock,
        'affiliateUrl': affiliateUrl,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreOffer &&
          other.storeName == storeName &&
          other.storeLogoUrl == storeLogoUrl &&
          other.price == price &&
          other.inStock == inStock &&
          other.affiliateUrl == affiliateUrl;

  @override
  int get hashCode => Object.hash(storeName, storeLogoUrl, price, inStock, affiliateUrl);

  @override
  String toString() => 'StoreOffer($storeName, €$price, inStock: $inStock)';
}
