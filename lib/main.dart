import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/errors/app_exceptions.dart';
import 'presentation/router/app_router.dart';
import 'presentation/theme/app_colors.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(retry: _retryPolicy, child: RadarPriceApp()));
}

/// No se reintentan errores de programación ([Error]) ni [AppException] no transitorias.
/// Red / timeout / 5xx: 3 reintentos con backoff 200/400/800 ms.
Duration? _retryPolicy(int retryCount, Object error) {
  if (error is Error) return null;
  if (error is AppException && !error.isRetryable) return null;
  if (retryCount >= 3) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}

class RadarPriceApp extends StatelessWidget {
  const RadarPriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.dark;
    return MaterialApp(
      title: 'RadarPrice',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      initialRoute: AppRouter.shell,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
