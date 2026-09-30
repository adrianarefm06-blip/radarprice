import 'package:flutter/foundation.dart' show immutable;

/// Alerta de precio del dispositivo. El servidor asigna [id] y evalúa el disparo
/// en cada sync; la app solo refleja su estado.
///
/// [targetSize] == `null` → cualquier talla.
@immutable
class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.productId,
    required this.sku,
    required this.targetPrice,
    required this.isActive,
    required this.createdAt,
    this.targetSize,
    this.triggeredAt,
    this.triggeredPrice,
    this.currentPrice,
    this.brand,
    this.productName,
  });

  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(
        id: json['id'] as String,
        productId: json['productId'] as String,
        sku: json['sku'] as String,
        targetPrice: (json['targetPrice'] as num).toDouble(),
        targetSize: json['targetSize'] as String?,
        isActive: json['isActive'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        triggeredAt: switch (json['triggeredAt']) {
          final String value => DateTime.parse(value),
          _ => null,
        },
        triggeredPrice: (json['triggeredPrice'] as num?)?.toDouble(),
        currentPrice: (json['currentPrice'] as num?)?.toDouble(),
        brand: json['brand'] as String?,
        productName: json['productName'] as String?,
      );

  final String id;
  final String productId;
  final String sku;
  final double targetPrice;
  final String? targetSize;
  final bool isActive;
  final DateTime createdAt;

  /// Último cruce del objetivo; `null` si no se ha cumplido (o volvió a subir).
  final DateTime? triggeredAt;
  final double? triggeredPrice;

  /// Precio actual según el servidor (en la talla si se fijó). `null` = sin stock.
  final double? currentPrice;

  /// Para mostrar la alerta sin cargar el producto (p. ej. en una notificación). API antigua → null.
  final String? brand;
  final String? productName;

  /// "adidas Campus 00s …" o, sin nombre, el SKU.
  String get displayName => switch ((brand, productName)) {
        (final String b, final String n) => '$b $n',
        (_, final String n) => n,
        _ => sku,
      };

  bool get isTriggered => isActive && triggeredAt != null;

  PriceAlert copyWith({bool? isActive, double? targetPrice}) => PriceAlert(
        id: id,
        productId: productId,
        sku: sku,
        targetPrice: targetPrice ?? this.targetPrice,
        targetSize: targetSize,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        // Pausar limpia el disparo (el servidor hace lo mismo al reevaluar).
        triggeredAt: (isActive ?? this.isActive) ? triggeredAt : null,
        triggeredPrice: (isActive ?? this.isActive) ? triggeredPrice : null,
        currentPrice: currentPrice,
        brand: brand,
        productName: productName,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'sku': sku,
        'targetPrice': targetPrice,
        'targetSize': targetSize,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'triggeredAt': triggeredAt?.toIso8601String(),
        'triggeredPrice': triggeredPrice,
        'currentPrice': currentPrice,
        'brand': brand,
        'productName': productName,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceAlert &&
          other.id == id &&
          other.productId == productId &&
          other.sku == sku &&
          other.targetPrice == targetPrice &&
          other.targetSize == targetSize &&
          other.isActive == isActive &&
          other.createdAt == createdAt &&
          other.triggeredAt == triggeredAt &&
          other.triggeredPrice == triggeredPrice &&
          other.currentPrice == currentPrice &&
          other.brand == brand &&
          other.productName == productName;

  @override
  int get hashCode => Object.hash(
        id,
        productId,
        sku,
        targetPrice,
        targetSize,
        isActive,
        createdAt,
        triggeredAt,
        triggeredPrice,
        currentPrice,
        brand,
        productName,
      );

  @override
  String toString() =>
      'PriceAlert($id, $sku, size: ${targetSize ?? 'any'}, ≤€$targetPrice, active: $isActive, '
      'triggered: ${triggeredAt != null})';
}
