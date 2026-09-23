import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../../domain/services/store_catalog.dart';
import 'repository_providers.dart';

/// Catálogo completo sin filtro de talla. Fuente única de Chollos por tienda.
/// Refresh: `ref.refresh(allDealsProvider.future)`.
final allDealsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).getHotDeals(),
);

// Derivados síncronos con `whenData`: comparten la petición de [allDealsProvider],
// conservan el dato previo durante recargas y propagan el error original.

final storeSummariesProvider = Provider<AsyncValue<List<StoreSummary>>>(
  (ref) => ref.watch(allDealsProvider).whenData(buildStoreSummaries),
);

typedef StoreDealsParams = ({String storeName, String? size});

final storeDealsProvider =
    Provider.autoDispose.family<AsyncValue<List<StoreDealItem>>, StoreDealsParams>(
  (ref, params) => ref
      .watch(allDealsProvider)
      .whenData((products) => buildStoreDeals(products, params.storeName, size: params.size)),
);

final storeSizesProvider = Provider.autoDispose.family<List<String>, String>((ref, storeName) {
  final deals = ref.watch(allDealsProvider);
  return deals.hasValue ? availableSizesForStore(deals.requireValue, storeName) : const [];
});
