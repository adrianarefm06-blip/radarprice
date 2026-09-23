import 'package:flutter/foundation.dart' show immutable;

import 'product.dart';

/// Alerta de precio del usuario.
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
  });

  /// Alerta nueva, activa, con id local temporal.
  /// Con backend real, el id debe asignarlo el servidor.
  factory PriceAlert.draft({
    required String productId,
    required String sku,
    required double targetPrice,
    String? targetSize,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return PriceAlert(
      id: 'alert_${timestamp.microsecondsSinceEpoch}',
      productId: productId,
      sku: sku,
      targetPrice: targetPrice,
      targetSize: targetSize,
      isActive: true,
      createdAt: timestamp,
    );
  }

  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(
        id: json['id'] as String,
        productId: json['productId'] as String,
        sku: json['sku'] as String,
        targetPrice: (json['targetPrice'] as num).toDouble(),
        targetSize: json['targetSize'] as String?,
        isActive: json['isActive'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String productId;
  final String sku;
  final double targetPrice;
  final String? targetSize;
  final bool isActive;
  final DateTime createdAt;

  /// `true` si la alerta está activa y el precio actual cumple el objetivo.
  bool isTriggeredBy(Product product) {
    if (!isActive || product.sku != sku) return false;
    final size = targetSize;
    final current = size == null ? product.lowestPrice : product.lowestPriceForSize(size);
    return current != null && current <= targetPrice;
  }

  /// [targetSize] usa función para poder asignar `null` explícitamente:
  /// `alert.copyWith(targetSize: () => null)`.
  PriceAlert copyWith({
    String? id,
    String? productId,
    String? sku,
    double? targetPrice,
    String? Function()? targetSize,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      PriceAlert(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        sku: sku ?? this.sku,
        targetPrice: targetPrice ?? this.targetPrice,
        targetSize: targetSize != null ? targetSize() : this.targetSize,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'sku': sku,
        'targetPrice': targetPrice,
        'targetSize': targetSize,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
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
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, productId, sku, targetPrice, targetSize, isActive, createdAt);

  @override
  String toString() =>
      'PriceAlert($id, $sku, size: ${targetSize ?? 'any'}, ≤€$targetPrice, active: $isActive)';
}
