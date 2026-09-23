import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_alert_repository.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../infrastructure/repositories/http_product_repository.dart';

/// Emulador Android → host: 10.0.2.2. Dispositivo físico / otro entorno:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000`
const kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final repository = HttpProductRepository(baseUrl: kApiBaseUrl);
  ref.onDispose(repository.dispose);
  return repository;
});

/// Sin endpoints de alertas en la API aún: persistencia en memoria.
final alertRepositoryProvider = Provider<AlertRepository>(
  (ref) => MockAlertRepository(),
);
