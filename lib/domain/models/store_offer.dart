import 'package:flutter/foundation.dart' show immutable;

/// Oferta de una tienda concreta para una talla concreta. Precio en EUR.
/// [isSimulated] = dato de demostración (API con `source: "simulated"`): la UI lo marca como estimado.
@immutable
class StoreOffer {
  const StoreOffer({
    required this.storeName,
    required this.storeLogoUrl,
    required this.price,
    required this.inStock,
    required this.affiliateUrl,
    this.isSimulated = false,
  });

  factory StoreOffer.fromJson(Map<String, dynamic> json) => StoreOffer(
        storeName: json['storeName'] as String,
        storeLogoUrl: json['storeLogoUrl'] as String,
        price: (json['price'] as num).toDouble(),
        inStock: json['inStock'] as bool,
        affiliateUrl: json['affiliateUrl'] as String,
        // API antigua sin `source` → se asume real (no se inventa la marca).
        isSimulated: json['source'] == 'simulated',
      );

  final String storeName;
  final String storeLogoUrl;
  final double price;
  final bool inStock;
  final String affiliateUrl;
  final bool isSimulated;

  StoreOffer copyWith({
    String? storeName,
    String? storeLogoUrl,
    double? price,
    bool? inStock,
    String? affiliateUrl,
    bool? isSimulated,
  }) =>
      StoreOffer(
        storeName: storeName ?? this.storeName,
        storeLogoUrl: storeLogoUrl ?? this.storeLogoUrl,
        price: price ?? this.price,
        inStock: inStock ?? this.inStock,
        affiliateUrl: affiliateUrl ?? this.affiliateUrl,
        isSimulated: isSimulated ?? this.isSimulated,
      );

  Map<String, dynamic> toJson() => {
        'storeName': storeName,
        'storeLogoUrl': storeLogoUrl,
        'price': price,
        'inStock': inStock,
        'affiliateUrl': affiliateUrl,
        'source': isSimulated ? 'simulated' : 'live',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreOffer &&
          other.storeName == storeName &&
          other.storeLogoUrl == storeLogoUrl &&
          other.price == price &&
          other.inStock == inStock &&
          other.affiliateUrl == affiliateUrl &&
          other.isSimulated == isSimulated;

  @override
  int get hashCode => Object.hash(storeName, storeLogoUrl, price, inStock, affiliateUrl, isSimulated);

  @override
  String toString() => 'StoreOffer($storeName, €$price, inStock: $inStock${isSimulated ? ', simulated' : ''})';
}
