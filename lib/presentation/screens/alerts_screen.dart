import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/models/models.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/state_views.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    try {
      ref.invalidate(alertsProvider);
      await ref.read(alertsProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Alertas', style: text.headlineMedium),
          ),
          if (alerts.hasValue)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _summary(alerts.requireValue),
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: alerts.when(
                skipLoadingOnRefresh: true,
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (error, _) => PullToRefreshFill(
                  child: ErrorStateView(error: error, onRetry: () => ref.invalidate(alertsProvider)),
                ),
                data: (items) => items.isEmpty
                    ? const PullToRefreshFill(
                        child: StateMessageView(
                          icon: Icons.notifications_off_outlined,
                          title: 'Aún no tienes alertas',
                          message: 'Abre una zapatilla y pulsa la campana para saber cuándo baja de tu precio.',
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) => _AlertTile(key: ValueKey(items[index].id), alert: items[index]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _summary(List<PriceAlert> alerts) {
    final active = alerts.where((a) => a.isActive).length;
    final reached = alerts.where((a) => a.isTriggered).length;
    if (alerts.isEmpty) return 'Te avisamos cuando una zapatilla baje de tu precio';
    final base = active == 1 ? '1 activa de ${alerts.length}' : '$active activas de ${alerts.length}';
    return reached == 0 ? base : '$base · $reached con precio alcanzado';
  }
}

class _AlertTile extends ConsumerWidget {
  const _AlertTile({super.key, required this.alert});

  final PriceAlert alert;

  Future<void> _setActive(BuildContext context, WidgetRef ref, bool isActive) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(alertsProvider.notifier).setActive(alert.id, isActive: isActive);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(alertsProvider.notifier).delete(alert.id);
      messenger.showSnackBar(SnackBar(content: Text('Alerta de $name eliminada')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productBySkuProvider(alert.sku));
    final product = productAsync.hasValue ? productAsync.requireValue : null;
    final text = Theme.of(context).textTheme;
    final size = alert.targetSize;
    final name = product?.displayName ?? alert.sku;

    return Dismissible(
      key: ValueKey('dismiss-${alert.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.background),
      ),
      onDismissed: (_) => _delete(context, ref, name),
      child: AnimatedOpacity(
        opacity: alert.isActive ? 1 : 0.55,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: product == null ? null : () => AppRouter.openProduct(context, product),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          '${size == null ? 'Cualquier talla' : 'EU $size'}, por debajo de ${formatPrice(alert.targetPrice)}',
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        _Status(alert: alert),
                      ],
                    ),
                  ),
                  Switch(
                    value: alert.isActive,
                    onChanged: (value) => _setActive(context, ref, value),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.alert});

  final PriceAlert alert;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final price = alert.currentPrice;
    final triggeredAt = alert.triggeredAt;
    if (alert.isTriggered && triggeredAt != null) {
      return Text(
        'Precio alcanzado: ${formatPrice(alert.triggeredPrice ?? price ?? alert.targetPrice)} · '
        '${formatShortDate(triggeredAt.toLocal())}',
        style: AppTypography.price(fontSize: 16, color: AppColors.deal),
      );
    }
    if (price == null) {
      return Text(
        alert.targetSize == null ? 'Sin stock ahora mismo' : 'Agotado en esta talla',
        style: text.bodySmall,
      );
    }
    return Text(
      'Ahora desde ${formatPrice(price)}',
      style: AppTypography.price(fontSize: 16, color: AppColors.textSecondary),
    );
  }
}
