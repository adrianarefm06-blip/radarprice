import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository_providers.dart';

/// SKUs favoritos persistidos. Toggle optimista con rollback si falla la escritura.
class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async => Set.unmodifiable(await ref.watch(favoritesRepositoryProvider).load());

  bool isFavorite(String sku) => state.value?.contains(sku) ?? false;

  /// Devuelve el nuevo estado (`true` = añadido). Relanza el error de persistencia.
  Future<bool> toggleFavorite(String sku) async {
    // Espera la carga inicial: un toggle temprano no debe pisar lo guardado.
    final previous = state.value ?? await future;
    final added = !previous.contains(sku);
    final next = Set<String>.unmodifiable(added ? {...previous, sku} : ({...previous}..remove(sku)));
    state = AsyncData(next);
    try {
      await ref.read(favoritesRepositoryProvider).save(next);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
    return added;
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);

/// `ref.watch(isFavoriteProvider(sku))`: solo reconstruye el corazón de ese SKU.
final isFavoriteProvider = Provider.family<bool, String>(
  (ref, sku) => ref.watch(favoritesProvider.select((s) => s.value?.contains(sku) ?? false)),
);
