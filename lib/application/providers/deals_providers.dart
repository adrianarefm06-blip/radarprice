import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/deal_comparison.dart';
import 'filter_providers.dart';
import 'store_providers.dart';

/// Segmento activo del feed "Mejores chollos".
class DealSegmentFilter extends Notifier<DealSegment> {
  @override
  DealSegment build() => DealSegment.all;

  void select(DealSegment segment) => state = segment;
}

final dealSegmentProvider = NotifierProvider<DealSegmentFilter, DealSegment>(DealSegmentFilter.new);

// Derivados síncronos de [allDealsProvider]: cambiar talla o segmento solo
// recalcula en memoria (sin nueva petición) y conserva el dato durante recargas.

/// Tallas con stock en el segmento activo (chips del filtro).
final dealSizesProvider = Provider<List<String>>((ref) {
  final segment = ref.watch(dealSegmentProvider);
  final deals = ref.watch(allDealsProvider);
  return deals.hasValue ? availableDealSizes(deals.requireValue, segment: segment) : const [];
});

/// Chollos globales filtrados por talla ([selectedSizeFilterProvider]) y segmento,
/// ordenados por mayor descuento frente a retail.
final filteredDealsProvider = Provider<AsyncValue<List<DealComparison>>>((ref) {
  final size = ref.watch(selectedSizeFilterProvider);
  final segment = ref.watch(dealSegmentProvider);
  return ref
      .watch(allDealsProvider)
      .whenData((products) => buildDealComparisons(products, size: size, segment: segment));
});
