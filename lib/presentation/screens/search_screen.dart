import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/models/models.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/product_card.dart';
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

  /// Últimos resultados: se siguen mostrando mientras llega la búsqueda nueva
  /// (cada tecla crea una instancia distinta del provider family).
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

  @override
  Widget build(BuildContext context) {
    final size = ref.watch(selectedSizeFilterProvider);
    final results = ref.watch(productSearchProvider((query: _query, size: size)));
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
          const SizeSelector(),
          const SizedBox(height: 12),
          SizedBox(
            height: 2,
            child: results.isLoading && _lastResults != null ? const LinearProgressIndicator(minHeight: 2) : null,
          ),
          Expanded(child: _buildResults(results, size)),
        ],
      ),
    );
  }

  Widget _buildResults(AsyncValue<List<Product>> results, String? size) {
    if (results.hasError && !results.isLoading) {
      return ErrorStateView(
        error: results.error!,
        onRetry: () => ref.invalidate(productSearchProvider((query: _query, size: size))),
      );
    }

    final products = _lastResults;
    if (products == null) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const ProductCardSkeleton(),
      );
    }

    if (products.isEmpty) {
      return StateMessageView(
        icon: Icons.search_off_rounded,
        title: _query.isEmpty ? 'Sin stock en la EU $size' : 'Sin resultados para «$_query»',
        message: size == null
            ? 'Prueba con la marca, el modelo o el SKU completo, por ejemplo DD1391-100.'
            : 'Puede que no haya stock en la EU $size. Prueba con todas las tallas.',
      );
    }

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
          selectedSize: size,
          onTap: () => AppRouter.openProduct(context, product),
        );
      },
    );
  }
}
