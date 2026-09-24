import '../../domain/repositories/favorites_repository.dart';

/// Tests y previews: sin plataforma. [failWrites] simula error de disco.
class InMemoryFavoritesRepository implements FavoritesRepository {
  InMemoryFavoritesRepository([Set<String> initial = const {}]) : _skus = {...initial};

  Set<String> _skus;
  bool failWrites = false;

  Set<String> get stored => Set.unmodifiable(_skus);

  @override
  Future<Set<String>> load() async => {..._skus};

  @override
  Future<void> save(Set<String> skus) async {
    if (failWrites) throw StateError('Escritura de favoritos fallida');
    _skus = {...skus};
  }
}
