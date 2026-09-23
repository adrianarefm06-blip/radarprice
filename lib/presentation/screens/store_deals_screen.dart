import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/models/models.dart';
import '../../domain/services/store_catalog.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/product_card.dart';
import '../widgets/shimmer.dart';
import '../widgets/size_selector.dart';
import '../widgets/state_views.dart';
import '../widgets/store_card.dart';
import '../widgets/store_logo.dart';

/// Feed exclusivo de una tienda, filtrable por talla.
/// Las tarjetas muestran solo los precios de esta tienda; el detalle compara todas.
class StoreDealsScreen extends ConsumerWidget {
  const StoreDealsScreen({super.key, required this.storeName});

  final String storeName;

  Future<void> _refresh(WidgetRef ref) async {
    try {
      ref.invalidate(allDealsProvider);
      await ref.read(allDealsProvider.future);
    } catch (_) {
      // El error queda reflejado en el estado.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(selectedSizeFilterProvider);
    final deals = ref.watch(storeDealsProvider((storeName: storeName, size: size)));
    final storeSizes = ref.watch(storeSizesProvider(storeName));
    final summaries = ref.watch(storeSummariesProvider);
    final summary = summaries.hasValue
        ? summaries.requireValue.where((s) => s.storeName == storeName).firstOrNull
        : null;
    final text = Theme.of(context).textTheme;

    // La talla activa siempre visible, aunque esta tienda no la tenga en stock.
    final chipSizes = {...storeSizes, ?size}.toList()..sort(Product.compareSizes);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (summary != null) ...[
              StoreLogo(logoUrl: summary.storeLogoUrl, storeName: storeName, size: 28),
              const SizedBox(width: 10),
            ],
            Flexible(child: Text(storeName, style: text.titleLarge, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                StoreCard.offerCountLabel(summary.activeOfferCount),
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          if (chipSizes.isNotEmpty) ...[
            SizeSelector(sizes: chipSizes),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 2,
            child: deals.isLoading && deals.hasValue ? const LinearProgressIndicator(minHeight: 2) : null,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: deals.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, __) => const ProductCardSkeleton(),
                ),
                error: (error, _) => PullToRefreshFill(
                  child: ErrorStateView(error: error, onRetry: () => ref.invalidate(allDealsProvider)),
                ),
                data: (items) => items.isEmpty
                    ? PullToRefreshFill(
                        child: StateMessageView(
                          icon: Icons.do_not_disturb_on_outlined,
                          title: size == null ? 'Sin ofertas ahora' : 'Sin stock en la EU $size',
                          message: size == null
                              ? '$storeName no tiene stock de las zapatillas que seguimos. Vuelve a mirar más tarde.'
                              : '$storeName no tiene esta talla ahora mismo. Prueba con otra o mira todas.',
                          actionLabel: size == null ? null : 'Ver todas las tallas',
                          onAction: size == null ? null : ref.read(selectedSizeFilterProvider.notifier).clear,
                        ),
                      )
                    : _StoreDealsList(items: items, selectedSize: size),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreDealsList extends StatelessWidget {
  const _StoreDealsList({required this.items, required this.selectedSize});

  final List<StoreDealItem> items;
  final String? selectedSize;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return ProductCard(
          key: ValueKey(item.product.sku),
          product: item.storeView,
          selectedSize: selectedSize,
          onTap: () => AppRouter.openProduct(context, item.product),
        );
      },
    );
  }
}
