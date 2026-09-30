import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/alert_checks.dart';
import 'application/providers/providers.dart';
import 'core/errors/app_exceptions.dart';
import 'infrastructure/notifications/local_alert_notifications.dart';
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
  unawaited(_startAlertNotifications());
}

/// Avisos de alertas: tocar un aviso abre la zapatilla; comprobación periódica en segundo plano.
/// Nunca bloquea ni rompe el arranque.
Future<void> _startAlertNotifications() async {
  if (!alertNotificationsSupported) return;
  try {
    await LocalAlertNotifications.instance.init(onOpenSku: AppRouter.openSku);
    final launchSku = await LocalAlertNotifications.instance.launchSku();
    if (launchSku != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => AppRouter.openSku(launchSku));
    }
    await scheduleAlertChecks();
  } catch (error) {
    debugPrint('notificaciones: $error');
  }
}

/// No se reintentan errores de programación ([Error]) ni [AppException] no transitorias.
/// Red / timeout / 5xx: 3 reintentos con backoff 200/400/800 ms.
Duration? _retryPolicy(int retryCount, Object error) {
  if (error is Error) return null;
  if (error is AppException && !error.isRetryable) return null;
  if (retryCount >= 3) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}

/// Al abrir y al volver a la app: comprueba alertas (avisa de las nuevas) y refresca la pestaña.
class RadarPriceApp extends ConsumerStatefulWidget {
  const RadarPriceApp({super.key});

  @override
  ConsumerState<RadarPriceApp> createState() => _RadarPriceAppState();
}

class _RadarPriceAppState extends ConsumerState<RadarPriceApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _checkAlerts);
    _checkAlerts();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _checkAlerts() {
    if (!alertNotificationsSupported) return;
    unawaited(runAlertCheck().then((sent) {
      if (sent > 0 && mounted) ref.invalidate(alertsProvider);
    }).catchError((Object error) {
      debugPrint('alert-check: $error');
    }));
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.dark;
    return MaterialApp(
      title: 'RadarPrice',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      navigatorKey: AppRouter.navigatorKey,
      initialRoute: AppRouter.shell,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
