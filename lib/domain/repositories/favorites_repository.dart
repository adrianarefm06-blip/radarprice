/// Persistencia local de SKUs favoritos (lista de deseos).
abstract interface class FavoritesRepository {
  Future<Set<String>> load();

  /// Reemplaza el conjunto completo (escritura atómica de una sola clave).
  Future<void> save(Set<String> skus);
}
