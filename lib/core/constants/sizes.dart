/// Tallas EU del catálogo actual (Chollos, tiendas y detalle).
const List<String> kSupportedSizes = ['41', '42', '42.5', '43', '44'];

const List<String> kMenSizes = ['39', '40', '40.5', '41', '42', '42.5', '43', '44', '44.5', '45', '46'];
const List<String> kWomenSizes = ['35', '35.5', '36', '36.5', '37', '37.5', '38', '38.5', '39', '40', '41', '42'];
const List<String> kKidsSizes = ['28', '29', '30', '31', '32', '33', '34', '35', '36', '37', '38'];

/// Unión de todas las tallas válidas en la app (validación de filtros).
final Set<String> kAllSizes = Set.unmodifiable({
  ...kSupportedSizes,
  ...kMenSizes,
  ...kWomenSizes,
  ...kKidsSizes,
});

/// Segmentos del buscador. El orden de declaración es el orden visual.
enum SizeSegment {
  men(label: 'Hombre', sizesLabel: 'tallas de hombre', sizes: kMenSizes),
  women(label: 'Mujer', sizesLabel: 'tallas de mujer', sizes: kWomenSizes),
  kids(label: 'Niños', sizesLabel: 'tallas infantiles', sizes: kKidsSizes);

  const SizeSegment({required this.label, required this.sizesLabel, required this.sizes});

  final String label;
  final String sizesLabel;
  final List<String> sizes;
}
