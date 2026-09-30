import 'dart:async';

import 'package:radarprice/presentation/widgets/sneaker_image.dart';

/// Configuración común de todos los tests (Flutter la carga automáticamente).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SneakerImage.diskCache = false;
  await testMain();
}
