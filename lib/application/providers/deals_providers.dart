import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/deal_comparison.dart';
import 'favorites_providers.dart';
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

/// Comparativas por talla ([selectedSizeFilterProvider]) y segmento, por mayor descuento.
final segmentDealsProvider = Provider<AsyncValue<List<DealComparison>>>((ref) {
  final size = ref.watch(selectedSizeFilterProvider);
  final segment = ref.watch(dealSegmentProvider);
  return ref
      .watch(allDealsProvider)
      .whenData((products) => buildDealComparisons(products, size: size, segment: segment));
});

/// Texto de búsqueda aplicado (tras debounce). La UI llama a [setQuery] en cada tecla.
class DealQuery extends Notifier<String> {
  static const debounce = Duration(milliseconds: 300);

  Timer? _timer;

  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    return '';
  }

  void setQuery(String raw) {
    _timer?.cancel();
    final query = raw.trim();
    if (query.isEmpty) {
      state = ''; // Vaciar es inmediato: no hay nada que esperar.
      return;
    }
    _timer = Timer(debounce, () => state = query);
  }

  void clear() {
    _timer?.cancel();
    state = '';
  }
}

final dealQueryProvider = NotifierProvider<DealQuery, String>(DealQuery.new);

class DealSortNotifier extends Notifier<DealSort> {
  @override
  DealSort build() => DealSort.discount;

  void select(DealSort sort) => state = sort;
}

final dealSortProvider = NotifierProvider<DealSortNotifier, DealSort>(DealSortNotifier.new);

/// Filtro rápido "Mis favoritos".
class FavoritesOnlyFilter extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final favoritesOnlyProvider = NotifierProvider<FavoritesOnlyFilter, bool>(FavoritesOnlyFilter.new);

/// Feed final: comparativas + texto + favoritos + orden. Todo en memoria:
/// ningún filtro de esta cadena vuelve a pedir datos a la API.
final filteredDealsProvider = Provider<AsyncValue<List<DealComparison>>>((ref) {
  final query = ref.watch(dealQueryProvider);
  final sort = ref.watch(dealSortProvider);
  final favoritesOnly = ref.watch(favoritesOnlyProvider);
  final favorites = favoritesOnly ? ref.watch(favoritesProvider).value ?? const <String>{} : null;
  return ref
      .watch(segmentDealsProvider)
      .whenData((deals) => refineDeals(deals, query: query, onlySkus: favorites, sort: sort));
});
