import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/alert_repository.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../infrastructure/http/api_client.dart';
import '../../infrastructure/repositories/device_id_store.dart';
import '../../infrastructure/repositories/http_alert_repository.dart';
import '../../infrastructure/repositories/http_product_repository.dart';
import '../../infrastructure/repositories/shared_prefs_favorites_repository.dart';

/// Emulador Android → host: 10.0.2.2. Dispositivo físico / otro entorno:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000`
/// Release: obligatorio `--dart-define=API_BASE_URL=https://…` (HTTP se rechaza).
const kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

/// Espera máxima por petición. Holgada por defecto: en el plan gratuito de Render el
/// servidor se duerme y el primer acceso tarda en arrancar (después reintenta el ProviderScope).
/// `--dart-define=API_TIMEOUT_SECONDS=60` para ampliarla.
const kApiTimeout = Duration(seconds: int.fromEnvironment('API_TIMEOUT_SECONDS', defaultValue: 30));

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final repository = HttpProductRepository(baseUrl: kApiBaseUrl, timeout: kApiTimeout);
  ref.onDispose(repository.dispose);
  return repository;
});

/// Id aleatorio del dispositivo para las alertas (`X-Device-Id`).
final deviceIdStoreProvider = Provider<DeviceIdStore>((ref) => DeviceIdStore());

/// Alertas en el servidor, aisladas por dispositivo. Tests: override con `MockAlertRepository`.
final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  final api = ApiClient(baseUrl: kApiBaseUrl, timeout: kApiTimeout);
  ref.onDispose(api.dispose);
  return HttpAlertRepository(api: api, deviceId: ref.watch(deviceIdStoreProvider).read);
});

/// Favoritos en el dispositivo (shared_preferences). Tests: override en memoria.
final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => SharedPrefsFavoritesRepository(),
);
