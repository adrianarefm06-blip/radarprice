import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/models/models.dart';
import '../../domain/services/deal_comparison.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/store_launcher.dart';
import '../widgets/deal_comparison_card.dart';
import '../widgets/favorite_button.dart';
import '../widgets/segment_toggle.dart';
import '../widgets/shimmer.dart';
import '../widgets/size_selector.dart';
import '../widgets/state_views.dart';

/// Feed consolidado de todas las tiendas: filtros de segmento y talla + comparador.
/// Los filtros se desplazan con la lista (en móvil ocupaban media pantalla fijos).
/// Filtros y lista son widgets separados: cambiar un filtro solo reconstruye lo que depende de él.
class BestDealsView extends StatelessWidget {
  const BestDealsView({super.key});

  static const _listPadding = EdgeInsets.fromLTRB(16, 8, 16, 24);

  Future<void> _refresh(ProviderContainer container) async {
    try {
      container.invalidate(allDealsProvider);
      await container.read(allDealsProvider.future);
    } catch (_) {
      // El error queda reflejado en el estado; no romper el indicador.
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _refresh(ProviderScope.containerOf(context, listen: false)),
      child: const CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _DealsFilters()),
          SliverToBoxAdapter(child: SizedBox(height: 10)),
          _DealsProgress(),
          _DealsBody(),
        ],
      ),
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
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _DealSearchField()),
        const SizedBox(height: 10),
        const _QuickFilters(),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentToggle<DealSegment>(
            segments: DealSegment.values,
            selected: segment,
            labelOf: (s) => s.label,
            onChanged: ref.read(dealSegmentProvider.notifier).select,
          ),
        ),
        if (chipSizes.isNotEmpty) ...[const SizedBox(height: 10), SizeSelector(sizes: chipSizes)],
      ],
    );
  }
}

/// Campo de búsqueda. El debounce vive en [DealQuery]; aquí solo el controlador.
class _DealSearchField extends ConsumerStatefulWidget {
  const _DealSearchField();

  @override
  ConsumerState<_DealSearchField> createState() => _DealSearchFieldState();
}

class _DealSearchFieldState extends ConsumerState<_DealSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(dealQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: _controller,
      hintText: 'Busca modelo, marca, color o SKU',
      leading: const Icon(Icons.search_rounded, color: AppColors.textMuted),
      trailing: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: _clear,
                ),
        ),
      ],
      onChanged: ref.read(dealQueryProvider.notifier).setQuery,
      textInputAction: TextInputAction.search,
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
      constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control))),
    );
  }
}

/// "Mis favoritos" + selector de orden.
class _QuickFilters extends ConsumerWidget {
  const _QuickFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesOnly = ref.watch(favoritesOnlyProvider);
    final favoritesCount = ref.watch(favoritesProvider.select((s) => s.value?.length ?? 0));
    final sort = ref.watch(dealSortProvider);

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          FilterChip(
            avatar: Icon(
              favoritesOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: favoritesOnly ? AppColors.error : AppColors.textSecondary,
            ),
            label: Text(favoritesCount == 0 ? 'Mis favoritos' : 'Mis favoritos ($favoritesCount)'),
            selected: favoritesOnly,
            showCheckmark: false,
            onSelected: (_) => ref.read(favoritesOnlyProvider.notifier).toggle(),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<DealSort>(
            tooltip: 'Ordenar',
            initialValue: sort,
            onSelected: ref.read(dealSortProvider.notifier).select,
            itemBuilder: (_) => [
              for (final option in DealSort.values) PopupMenuItem(value: option, child: Text(option.label)),
            ],
            child: Chip(
              avatar: const Icon(Icons.swap_vert_rounded, size: 18, color: AppColors.textSecondary),
              label: Text(sort.label),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra fina de recarga (con datos previos visibles).
class _DealsProgress extends ConsumerWidget {
  const _DealsProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reloading = ref.watch(filteredDealsProvider.select((d) => d.isLoading && d.hasValue));
    return SliverToBoxAdapter(
      child: SizedBox(height: 2, child: reloading ? const LinearProgressIndicator(minHeight: 2) : null),
    );
  }
}

/// Lista, carga, error o vacío, siempre como sliver.
class _DealsBody extends ConsumerWidget {
  const _DealsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(filteredDealsProvider)
        .when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => SliverPadding(
            padding: BestDealsView._listPadding,
            sliver: SliverList.separated(
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const ProductCardSkeleton(),
            ),
          ),
          error: (error, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorStateView(error: error, onRetry: () => ref.invalidate(allDealsProvider)),
          ),
          data: (items) => items.isEmpty
              ? const SliverFillRemaining(hasScrollBody: false, child: _EmptyDeals())
              : _DealsSliverList(items: items),
        );
  }
}

class _EmptyDeals extends ConsumerWidget {
  const _EmptyDeals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(selectedSizeFilterProvider);
    final segment = ref.watch(dealSegmentProvider);
    final query = ref.watch(dealQueryProvider);
    final favoritesOnly = ref.watch(favoritesOnlyProvider);
    final segmentLabel = segment == DealSegment.all ? '' : ' (${segment.label})';

    // Prioridad: el filtro más restrictivo que el usuario ha tocado explica el vacío.
    if (favoritesOnly) {
      return StateMessageView(
        icon: Icons.favorite_border_rounded,
        title: 'Sin favoritos que mostrar',
        message:
            'Pulsa el corazón de una zapatilla para guardarla. '
            'Solo aparecen las que tienen stock con los filtros actuales.',
        actionLabel: 'Ver todos los chollos',
        onAction: ref.read(favoritesOnlyProvider.notifier).toggle,
      );
    }
    if (query.isNotEmpty) {
      return StateMessageView(
        icon: Icons.search_off_rounded,
        title: 'Sin resultados para "$query"',
        message: size == null
            ? 'Prueba con otra marca, modelo, color o SKU.'
            : 'Prueba con otro término o quita el filtro de la talla $size.',
      );
    }

    return StateMessageView(
      icon: Icons.do_not_disturb_on_outlined,
      title: size == null ? 'No hay ofertas en stock$segmentLabel' : 'No hay ofertas en stock para la talla $size',
      message: size == null
          ? 'Ninguna tienda tiene stock ahora mismo. Desliza hacia abajo para buscar de nuevo.'
          : 'Prueba con otra talla, cambia de segmento o mira todas las tallas.',
      actionLabel: size == null ? null : 'Ver todas las tallas',
      onAction: size == null ? null : ref.read(selectedSizeFilterProvider.notifier).clear,
    );
  }
}

class _DealsSliverList extends StatelessWidget {
  const _DealsSliverList({required this.items});

  final List<DealComparison> items;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: BestDealsView._listPadding,
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final deal = items[index];
          return DealComparisonCard(
            key: ValueKey(deal.product.sku),
            deal: deal,
            action: FavoriteButton(sku: deal.product.sku),
            onTap: () => AppRouter.openProduct(context, deal.product),
            onQuoteTap: (quote) {
              final offer = quote.offer;
              if (offer != null) openStoreOffer(context, offer);
            },
          );
        },
      ),
    );
  }
}
