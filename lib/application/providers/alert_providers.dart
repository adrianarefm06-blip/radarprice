import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import 'repository_providers.dart';

/// Estado de alertas con actualización optimista en toggle (rollback si falla).
/// Los errores de mutación se relanzan para que la UI muestre un SnackBar.
class AlertsNotifier extends AsyncNotifier<List<PriceAlert>> {
  @override
  Future<List<PriceAlert>> build() => ref.watch(alertRepositoryProvider).getAlerts();

  Future<void> toggle(String alertId) async {
    final previous = state.hasValue ? state.requireValue : null;
    if (previous != null) {
      state = AsyncData(List.unmodifiable([
        for (final alert in previous)
          if (alert.id == alertId) alert.copyWith(isActive: !alert.isActive) else alert,
      ]));
    }
    try {
      await ref.read(alertRepositoryProvider).toggleAlert(alertId);
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> create(PriceAlert alert) async {
    await ref.read(alertRepositoryProvider).createAlert(alert);
    final current = state.hasValue ? state.requireValue : const <PriceAlert>[];
    state = AsyncData(List.unmodifiable([alert, ...current]));
  }
}

final alertsProvider =
    AsyncNotifierProvider<AlertsNotifier, List<PriceAlert>>(AlertsNotifier.new);
