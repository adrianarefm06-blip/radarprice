import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/services/alert_notifications.dart';

/// Disparos ya notificados, en shared_preferences (compartido con el isolate de segundo plano).
class SharedPrefsNotifiedAlertsStore implements NotifiedAlertsStore {
  SharedPrefsNotifiedAlertsStore({SharedPreferencesAsync? prefs}) : _prefs = prefs ?? SharedPreferencesAsync();

  static const storageKey = 'notified_alert_triggers';

  final SharedPreferencesAsync _prefs;

  @override
  Future<Set<String>> load() async => {...?await _prefs.getStringList(storageKey)};

  @override
  Future<void> save(Set<String> keys) => _prefs.setStringList(storageKey, keys.toList());
}
