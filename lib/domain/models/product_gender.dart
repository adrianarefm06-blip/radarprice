/// Segmento de tallaje del producto (campo `gender` de la API).
enum ProductGender {
  men(label: 'Hombre', apiValue: 'men'),
  women(label: 'Mujer', apiValue: 'women'),
  unisex(label: 'Unisex', apiValue: 'unisex');

  const ProductGender({required this.label, required this.apiValue});

  final String label;
  final String apiValue;

  /// Valores desconocidos o ausentes (API antigua, mocks) → [unisex].
  static ProductGender fromApi(Object? value) =>
      values.firstWhere((g) => g.apiValue == value, orElse: () => ProductGender.unisex);
}
