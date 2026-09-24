import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import 'repository_providers.dart';

/// Alertas del dispositivo. Pausar y borrar son optimistas (rollback si falla);
/// crear inserta la alerta que devuelve el servidor (ya evaluada).
/// Los errores de mutación se relanzan para que la UI los muestre.
class AlertsNotifier extends AsyncNotifier<List<PriceAlert>> {
  @override
  Future<List<PriceAlert>> build() => ref.watch(alertRepositoryProvider).getAlerts();

  List<PriceAlert>? get _current => state.hasValue ? state.requireValue : null;

  Future<void> setActive(String alertId, {required bool isActive}) async {
    final previous = _current;
    if (previous != null) {
      state = AsyncData(List.unmodifiable([
        for (final alert in previous)
          if (alert.id == alertId) alert.copyWith(isActive: isActive) else alert,
      ]));
    }
    try {
      final updated = await ref.read(alertRepositoryProvider).setActive(alertId, isActive: isActive);
      final current = _current ?? const <PriceAlert>[];
      state = AsyncData(List.unmodifiable([for (final a in current) a.id == alertId ? updated : a]));
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<PriceAlert> create({required String sku, required double targetPrice, String? targetSize}) async {
    final created = await ref
        .read(alertRepositoryProvider)
        .createAlert(sku: sku, targetPrice: targetPrice, targetSize: targetSize);
    final current = _current ?? const <PriceAlert>[];
    state = AsyncData(List.unmodifiable([created, ...current.where((a) => a.id != created.id)]));
    return created;
  }

  Future<void> delete(String alertId) async {
    final previous = _current;
    if (previous != null) {
      state = AsyncData(List.unmodifiable(previous.where((a) => a.id != alertId)));
    }
    try {
      await ref.read(alertRepositoryProvider).deleteAlert(alertId);
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}

final alertsProvider = AsyncNotifierProvider<AlertsNotifier, List<PriceAlert>>(AlertsNotifier.new);

/// Alertas activas cuyo objetivo se ha cumplido (badge de la pestaña).
final triggeredAlertCountProvider = Provider<int>(
  (ref) => ref.watch(alertsProvider.select((s) => s.value?.where((a) => a.isTriggered).length ?? 0)),
);

/// Alerta existente para esa zapatilla y talla (`null` = cualquier talla), si la hay.
typedef AlertKey = ({String sku, String? size});

final alertForProvider = Provider.family<PriceAlert?, AlertKey>((ref, key) {
  final alerts = ref.watch(alertsProvider).value ?? const <PriceAlert>[];
  for (final alert in alerts) {
    if (alert.sku == key.sku && alert.targetSize == key.size) return alert;
  }
  return null;
});

/// ¿Hay alguna alerta (de cualquier talla) para el SKU? Icono de campana del detalle.
final hasAlertForSkuProvider = Provider.family<bool, String>(
  (ref, sku) => ref.watch(alertsProvider.select((s) => s.value?.any((a) => a.sku == sku) ?? false)),
);
