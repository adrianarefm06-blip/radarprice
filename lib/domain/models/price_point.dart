import 'package:flutter/foundation.dart' show immutable;

/// Punto del histórico de precios (precio mínimo del día, EUR).
@immutable
class PricePoint {
  const PricePoint({required this.date, required this.price});

  factory PricePoint.fromJson(Map<String, dynamic> json) => PricePoint(
        date: DateTime.parse(json['date'] as String),
        price: (json['price'] as num).toDouble(),
      );

  final DateTime date;
  final double price;

  PricePoint copyWith({DateTime? date, double? price}) =>
      PricePoint(date: date ?? this.date, price: price ?? this.price);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'price': price,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PricePoint && other.date == date && other.price == price;

  @override
  int get hashCode => Object.hash(date, price);

  @override
  String toString() => 'PricePoint(${date.toIso8601String()}, €$price)';
}
