import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/models/models.dart';
import '../../domain/services/deal_comparison.dart';
import '../router/app_router.dart';
import '../utils/store_launcher.dart';
import '../widgets/deal_comparison_card.dart';
import '../widgets/segment_toggle.dart';
import '../widgets/shimmer.dart';
import '../widgets/size_selector.dart';
import '../widgets/state_views.dart';

/// Feed consolidado de todas las tiendas: filtros de segmento y talla + comparador.
/// Filtros y lista son widgets separados: cambiar un filtro solo reconstruye lo que depende de él.
class BestDealsView extends StatelessWidget {
  const BestDealsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DealsFilters(),
        SizedBox(height: 10),
        Expanded(child: _DealsList()),
      ],
    );
  }
}

class _DealsFilters extends ConsumerWidget {
  const _DealsFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(dealSegmentProvider);
    final sizes = ref.watch(dealSizesProvider);
    final selected = ref.watch(selectedSizeFilterProvider);
    // La talla activa siempre visible (p. ej. tras cambiar de segmento) para poder quitarla.
    final chipSizes = {...sizes, ?selected}.toList()..sort(Product.compareSizes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentToggle<DealSegment>(
            segments: DealSegment.values,
            selected: segment,
            labelOf: (s) => s.label,
            onChanged: ref.read(dealSegmentProvider.notifier).select,
          ),
        ),
        if (chipSizes.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizeSelector(sizes: chipSizes),
        ],
      ],
    );
  }
}

class _DealsList extends ConsumerWidget {
  const _DealsList();

  static const _padding = EdgeInsets.fromLTRB(16, 8, 16, 24);

  Future<void> _refresh(WidgetRef ref) async {
    try {
      ref.invalidate(allDealsProvider);
      await ref.read(allDealsProvider.future);
    } catch (_) {
      // El error queda reflejado en el estado; no romper el indicador.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(filteredDealsProvider);

    return Column(
      children: [
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
                padding: _padding,
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) => const ProductCardSkeleton(),
              ),
              error: (error, _) => PullToRefreshFill(
                child: ErrorStateView(error: error, onRetry: () => ref.invalidate(allDealsProvider)),
              ),
              data: (items) => items.isEmpty ? const _EmptyDeals() : _DealsListView(items: items),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyDeals extends ConsumerWidget {
  const _EmptyDeals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(selectedSizeFilterProvider);
    final segment = ref.watch(dealSegmentProvider);
    final segmentLabel = segment == DealSegment.all ? '' : ' (${segment.label})';

    return PullToRefreshFill(
      child: StateMessageView(
        icon: Icons.do_not_disturb_on_outlined,
        title: size == null ? 'No hay ofertas en stock$segmentLabel' : 'No hay ofertas en stock para la talla $size',
        message: size == null
            ? 'Ninguna tienda tiene stock ahora mismo. Desliza hacia abajo para buscar de nuevo.'
            : 'Prueba con otra talla, cambia de segmento o mira todas las tallas.',
        actionLabel: size == null ? null : 'Ver todas las tallas',
        onAction: size == null ? null : ref.read(selectedSizeFilterProvider.notifier).clear,
      ),
    );
  }
}

class _DealsListView extends StatelessWidget {
  const _DealsListView({required this.items});

  final List<DealComparison> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _DealsList._padding,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final deal = items[index];
        return DealComparisonCard(
          key: ValueKey(deal.product.sku),
          deal: deal,
          onTap: () => AppRouter.openProduct(context, deal.product),
          onQuoteTap: (quote) {
            final offer = quote.offer;
            if (offer != null) openStoreOffer(context, offer);
          },
        );
      },
    );
  }
}
