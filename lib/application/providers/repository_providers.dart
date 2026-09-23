import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_alert_repository.dart';
import '../../data/mock/mock_product_repository.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/repositories/product_repository.dart';

/// Punto único de inyección. Para el backend real, sustituir la implementación
/// aquí o vía `ProviderScope(overrides: [...])` — la UI no cambia.
final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => MockProductRepository(),
);

/// No autoDispose: el mock mantiene el estado en memoria durante la sesión.
final alertRepositoryProvider = Provider<AlertRepository>(
  (ref) => MockAlertRepository(),
);
