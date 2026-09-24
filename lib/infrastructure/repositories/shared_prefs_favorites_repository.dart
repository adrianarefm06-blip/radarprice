import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/favorites_repository.dart';

class SharedPrefsFavoritesRepository implements FavoritesRepository {
  SharedPrefsFavoritesRepository({SharedPreferencesAsync? prefs}) : _prefs = prefs ?? SharedPreferencesAsync();

  static const storageKey = 'favorite_skus';

  final SharedPreferencesAsync _prefs;

  @override
  Future<Set<String>> load() async => {...?await _prefs.getStringList(storageKey)};

  @override
  Future<void> save(Set<String> skus) => _prefs.setStringList(storageKey, (skus.toList()..sort()));
}
