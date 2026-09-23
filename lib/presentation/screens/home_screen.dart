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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    try {
      ref.invalidate(hotDealsProvider);
      await ref.read(hotDealsProvider.future);
    } catch (_) {
      // El error ya se refleja en el estado del provider; no romper el indicador.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(hotDealsProvider);
    final size = ref.watch(selectedSizeFilterProvider);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('RadarPrice', style: text.headlineMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              size == null ? 'Los mayores descuentos en todas las tallas' : 'Los mayores descuentos en la EU $size',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizeSelector(),
          const SizedBox(height: 12),
          // Recarga al cambiar de talla: se mantiene el feed anterior y se marca arriba.
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
                loading: () => const _FeedSkeleton(),
                error: (error, _) => PullToRefreshFill(
                  child: ErrorStateView(error: error, onRetry: () => ref.invalidate(hotDealsProvider)),
                ),
                data: (products) => products.isEmpty
                    ? PullToRefreshFill(
                        child: StateMessageView(
                          icon: Icons.do_not_disturb_on_outlined,
                          title: size == null ? 'No hay ofertas ahora mismo' : 'Sin stock en la EU $size',
                          message: 'Ninguna tienda tiene ofertas en esta talla ahora mismo. Crea una alerta o prueba con otra talla.',
                          actionLabel: 'Ver todas las tallas',
                          onAction: ref.read(selectedSizeFilterProvider.notifier).clear,
                        ),
                      )
                    : _DealsList(products: products, selectedSize: size),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DealsList extends StatelessWidget {
  const _DealsList({required this.products, required this.selectedSize});

  final List<Product> products;
  final String? selectedSize;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          key: ValueKey(product.sku),
          product: product,
          selectedSize: selectedSize,
          onTap: () => AppRouter.openProduct(context, product),
        );
      },
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando ofertas',
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const ProductCardSkeleton(),
      ),
    );
  }
}
