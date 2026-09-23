import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../core/constants/sizes.dart';
import '../../domain/models/models.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/product_card.dart';
import '../widgets/segment_toggle.dart';
import '../widgets/shimmer.dart';
import '../widgets/size_selector.dart';
import '../widgets/state_views.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  /// Últimos resultados visibles mientras llega la búsqueda nueva
  /// (cada tecla / talla crea una instancia distinta del provider family).
  List<Product>? _lastResults;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final trimmed = value.trim();
    if (trimmed != _query) setState(() => _query = trimmed);
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  /// Con talla → filtra el servidor. Con "Todas" → productos con stock en
  /// alguna talla del segmento activo.
  static List<Product> _applySegment(List<Product> products, SearchSizeFilter filter) =>
      filter.size != null
          ? products
          : [for (final p in products) if (filter.segment.sizes.any(p.isAvailableInSize)) p];

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(searchSizeFilterProvider);
    final filterNotifier = ref.read(searchSizeFilterProvider.notifier);
    final params = (query: _query, size: filter.size);
    final results = ref.watch(productSearchProvider(params));
    if (results.hasValue) _lastResults = results.requireValue;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Text('Buscar', style: text.headlineMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, value, _) => TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Marca, modelo o SKU',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar búsqueda',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _clear,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentToggle<SizeSegment>(
              segments: SizeSegment.values,
              selected: filter.segment,
              labelOf: (segment) => segment.label,
              onChanged: filterNotifier.selectSegment,
            ),
          ),
          const SizedBox(height: 12),
          SizeChipsBar(
            sizes: filter.segment.sizes,
            selected: filter.size,
            onSelected: (size) => size == null ? filterNotifier.selectSize(null) : filterNotifier.toggleSize(size),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 2,
            child: results.isLoading && _lastResults != null ? const LinearProgressIndicator(minHeight: 2) : null,
          ),
          Expanded(child: _buildResults(results, filter, params)),
        ],
      ),
    );
  }

  Widget _buildResults(AsyncValue<List<Product>> results, SearchSizeFilter filter, ProductSearchParams params) {
    if (results.hasError && !results.isLoading) {
      return ErrorStateView(
        error: results.error!,
        onRetry: () => ref.invalidate(productSearchProvider(params)),
      );
    }

    final raw = _lastResults;
    if (raw == null) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const ProductCardSkeleton(),
      );
    }

    final products = _applySegment(raw, filter);
    if (products.isEmpty) return _EmptyResults(query: _query, filter: filter);

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: products.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              products.length == 1 ? '1 resultado' : '${products.length} resultados',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          );
        }
        final product = products[index - 1];
        return ProductCard(
          key: ValueKey(product.sku),
          product: product,
          selectedSize: filter.size,
          onTap: () => AppRouter.openProduct(context, product),
        );
      },
    );
  }
}

class _EmptyResults extends ConsumerWidget {
  const _EmptyResults({required this.query, required this.filter});

  final String query;
  final SearchSizeFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = filter.size;
    final scope = size == null ? filter.segment.sizesLabel : 'la EU $size';

    return StateMessageView(
      icon: Icons.search_off_rounded,
      title: query.isEmpty ? 'Sin stock en $scope' : 'Sin resultados para «$query»',
      message: query.isEmpty
          ? 'Ninguna tienda tiene zapatillas en $scope ahora mismo.'
          : 'No hay coincidencias con stock en $scope. Prueba con la marca o el SKU, por ejemplo DD1391-100.',
      actionLabel: size == null ? null : 'Ver todas las tallas',
      onAction: size == null ? null : () => ref.read(searchSizeFilterProvider.notifier).selectSize(null),
    );
  }
}
