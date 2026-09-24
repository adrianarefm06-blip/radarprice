import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Id aleatorio del dispositivo (128 bits, hex) para `X-Device-Id`.
/// Se genera una vez y se persiste; nunca se muestra al usuario.
class DeviceIdStore {
  DeviceIdStore({SharedPreferencesAsync? prefs, Random? random})
      : _prefs = prefs ?? SharedPreferencesAsync(),
        _random = random ?? Random.secure();

  static const storageKey = 'device_id';
  static final _valid = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

  final SharedPreferencesAsync _prefs;
  final Random _random;
  Future<String>? _cached;

  /// Llamadas concurrentes comparten la misma lectura/generación.
  Future<String> read() => _cached ??= _loadOrCreate().catchError((Object e) {
        _cached = null; // no cachear un fallo de almacenamiento
        throw e;
      });

  Future<String> _loadOrCreate() async {
    final stored = await _prefs.getString(storageKey);
    if (stored != null && _valid.hasMatch(stored)) return stored;
    final id = [for (var i = 0; i < 16; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
    await _prefs.setString(storageKey, id);
    return id;
  }
}
