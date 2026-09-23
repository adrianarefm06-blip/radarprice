import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../domain/models/models.dart';
import 'filter_providers.dart';
import 'repository_providers.dart';

// -----------------------------------------------------------------------------
// Feed principal
// -----------------------------------------------------------------------------

/// Hot deals reactivos a la talla seleccionada.
/// - Sin talla: orden del repositorio (mayor ahorro global).
/// - Con talla: solo productos con stock en ella, ordenados por ahorro en esa talla.
///
/// Pull-to-refresh: `onRefresh: () => ref.refresh(hotDealsProvider.future)`.
class HotDealsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    final repository = ref.watch(productRepositoryProvider);
    final size = ref.watch(selectedSizeFilterProvider);
    final deals = await repository.getHotDeals();
    return size == null ? deals : _rankForSize(deals, size);
  }

  static List<Product> _rankForSize(List<Product> products, String size) {
    final available = products.where((p) => p.isAvailableInSize(size)).toList()
      ..sort((a, b) => (b.savingsPercentForSize(size) ?? double.negativeInfinity)
          .compareTo(a.savingsPercentForSize(size) ?? double.negativeInfinity));
    return List.unmodifiable(available);
  }
}

final hotDealsProvider =
    AsyncNotifierProvider<HotDealsNotifier, List<Product>>(HotDealsNotifier.new);

// -----------------------------------------------------------------------------
// Búsqueda
// -----------------------------------------------------------------------------

/// Parámetro de familia. Los records tienen igualdad estructural → cache correcta.
typedef ProductSearchParams = ({String query, String? size});

const _searchDebounce = Duration(milliseconds: 250);

/// Uso desde la UI (search-as-you-type):
/// ```dart
/// final size = ref.watch(selectedSizeFilterProvider);
/// final results = ref.watch(productSearchProvider((query: text, size: size)));
/// ```
/// Cada tecla crea una nueva instancia; la anterior se descarta (autoDispose)
/// durante el debounce sin llegar a pedir al repositorio.
final productSearchProvider =
    FutureProvider.autoDispose.family<List<Product>, ProductSearchParams>((ref, params) async {
  final repository = ref.watch(productRepositoryProvider);

  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future<void>.delayed(_searchDebounce);
  if (disposed) throw const RequestCancelledException();

  return repository.searchProducts(params.query.trim(), size: params.size);
});

// -----------------------------------------------------------------------------
// Detalle de producto
// -----------------------------------------------------------------------------

final productBySkuProvider =
    FutureProvider.autoDispose.family<Product, String>((ref, sku) {
  return ref.watch(productRepositoryProvider).getProductBySku(sku);
});

typedef PriceHistoryParams = ({String sku, int days});

/// `ref.watch(priceHistoryProvider((sku: product.sku, days: 90)))`
final priceHistoryProvider =
    FutureProvider.autoDispose.family<List<PricePoint>, PriceHistoryParams>((ref, params) {
  return ref.watch(productRepositoryProvider).getPriceHistory(params.sku, days: params.days);
});
