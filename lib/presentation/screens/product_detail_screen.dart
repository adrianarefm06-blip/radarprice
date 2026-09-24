import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/store_launcher.dart';
import '../widgets/discount_badge.dart';
import '../widgets/favorite_button.dart';
import '../widgets/price_history_chart.dart';
import '../widgets/price_line.dart';
import '../widgets/product_card.dart';
import '../widgets/product_pricing.dart';
import '../widgets/size_selector.dart';
import '../widgets/sneaker_image.dart';
import '../widgets/state_views.dart';
import '../widgets/store_logo.dart';

/// Detalle base: comparador de tiendas por talla.
/// Pinta [initialProduct] al instante y se actualiza con [productBySkuProvider].
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.sku, this.initialProduct});

  final String sku;
  final Product? initialProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productBySkuProvider(sku));
    final product = productAsync.hasValue ? productAsync.requireValue : initialProduct;

    return Scaffold(
      appBar: AppBar(actions: [FavoriteButton(sku: sku), const SizedBox(width: 8)]),
      body: product != null
          ? _DetailBody(product: product)
          : productAsync.hasError
              ? ErrorStateView(error: productAsync.error!, onRetry: () => ref.invalidate(productBySkuProvider(sku)))
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(selectedSizeFilterProvider);
    final pricing = ProductPricing.of(product, size);
    final text = Theme.of(context).textTheme;
    final savings = pricing.savingsPercent;
    // Tallas reales del producto (API). La activa se muestra aunque no exista aquí
    // (viene de otra pantalla) para que el usuario pueda cambiarla o quitarla.
    final productSizes = product.sizeOffers.keys.toList()..sort(Product.compareSizes);
    final chipSizes = {...productSizes, ?size}.toList()..sort(Product.compareSizes);
    final soldOut = product.availableSizes.isEmpty;
    final sizeOffers = size == null ? const <StoreOffer>[] : product.offersForSize(size);
    final colorway = product.colorway;

    Widget pad(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        pad(
          AspectRatio(
            aspectRatio: 1.25,
            child: Hero(
              tag: ProductCard.heroTagFor(product.sku),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ColoredBox(
                  color: AppColors.imageTile,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SneakerImage(imageUrl: product.imageUrl, brand: product.brand),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        pad(Text(product.brand, style: text.labelLarge)),
        const SizedBox(height: 2),
        pad(Text(product.model, style: text.headlineSmall)),
        if (colorway != null && colorway.isNotEmpty) ...[
          const SizedBox(height: 2),
          pad(Text(colorway, style: text.bodyMedium?.copyWith(color: AppColors.textSecondary))),
        ],
        const SizedBox(height: 14),
        pad(
          Row(
            children: [
              Expanded(child: PriceLine(pricing: pricing, priceFontSize: 34)),
              if (savings != null && DiscountBadge.shouldShow(savings)) DiscountBadge(savingsPercent: savings),
            ],
          ),
        ),
        const SizedBox(height: 6),
        pad(Text('SKU ${product.sku}', style: text.bodySmall?.copyWith(color: AppColors.textMuted))),
        const SizedBox(height: 28),
        if (soldOut)
          pad(const _SoldOutNotice())
        else ...[
          pad(Text('Tu talla', style: text.titleSmall)),
          const SizedBox(height: 10),
          SizeSelector(sizes: chipSizes),
          const SizedBox(height: 24),
          pad(Text(size == null ? 'Mejor precio por talla' : 'Tiendas con la EU $size', style: text.titleSmall)),
          const SizedBox(height: 10),
          if (size == null)
            for (final productSize in productSizes)
              pad(
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SizeRow(
                    size: productSize,
                    offer: product.bestOfferForSize(productSize),
                    onTap: () => ref.read(selectedSizeFilterProvider.notifier).select(productSize),
                  ),
                ),
              )
          else if (sizeOffers.isEmpty)
            pad(
              Text(
                'Ninguna tienda vende este modelo en la EU $size.',
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            for (final offer in sizeOffers)
              pad(Padding(padding: const EdgeInsets.only(bottom: 8), child: _OfferRow(offer: offer))),
        ],
        const SizedBox(height: 28),
        pad(PriceHistoryChart(product: product)),
      ],
    );
  }
}

/// Sin stock en ninguna talla ni tienda.
class _SoldOutNotice extends StatelessWidget {
  const _SoldOutNotice();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Agotado temporalmente', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Ninguna tienda tiene tallas disponibles ahora mismo. Vuelve a mirar más tarde.',
                  style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeRow extends StatelessWidget {
  const _SizeRow({required this.size, required this.offer, required this.onTap});

  final String size;
  final StoreOffer? offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final best = offer;
    return _RowShell(
      onTap: onTap,
      leading: SizedBox(
        width: 64,
        child: Text('EU $size', style: AppTypography.price(fontSize: 17)),
      ),
      middle: Text(
        best == null ? 'Agotado' : best.storeName,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      trailing: best == null
          ? null
          : Text(formatPrice(best.price), style: AppTypography.price(fontSize: 20)),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer});

  final StoreOffer offer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: offer.inStock ? 1 : 0.5,
      child: _RowShell(
        onTap: offer.inStock ? () => openStoreOffer(context, offer) : null,
        leading: StoreLogo(logoUrl: offer.storeLogoUrl, storeName: offer.storeName, size: 28),
        middle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(offer.storeName, style: text.titleSmall),
            const SizedBox(height: 2),
            Text(
              offer.inStock ? 'En stock' : 'Agotado',
              style: text.bodySmall?.copyWith(color: offer.inStock ? AppColors.deal : AppColors.textMuted),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatPrice(offer.price), style: AppTypography.price(fontSize: 20)),
            if (offer.inStock) ...[
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({required this.leading, required this.middle, this.trailing, this.onTap});

  final Widget leading;
  final Widget middle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trailingWidget = trailing;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: middle),
              if (trailingWidget != null) ...[const SizedBox(width: 12), trailingWidget],
            ],
          ),
        ),
      ),
    );
  }
}
