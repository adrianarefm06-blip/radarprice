import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers/providers.dart';
import '../../domain/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/discount_badge.dart';
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
      appBar: AppBar(),
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
        pad(Text('Tu talla', style: text.titleSmall)),
        const SizedBox(height: 10),
        const SizeSelector(),
        const SizedBox(height: 24),
        pad(Text(size == null ? 'Mejor precio por talla' : 'Tiendas con la EU $size', style: text.titleSmall)),
        const SizedBox(height: 10),
        if (size == null)
          for (final entry in _bestBySize(product))
            pad(
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SizeRow(
                  size: entry.$1,
                  offer: entry.$2,
                  onTap: () => ref.read(selectedSizeFilterProvider.notifier).select(entry.$1),
                ),
              ),
            )
        else
          for (final offer in product.offersForSize(size))
            pad(Padding(padding: const EdgeInsets.only(bottom: 8), child: _OfferRow(offer: offer))),
        const SizedBox(height: 28),
        pad(PriceHistoryChart(product: product)),
      ],
    );
  }

  static List<(String, StoreOffer?)> _bestBySize(Product product) {
    final sizes = product.sizeOffers.keys.toList()..sort(Product.compareSizes);
    return [for (final size in sizes) (size, product.bestOfferForSize(size))];
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

  /// Abre la tienda fuera de la app (navegador o app nativa de la tienda).
  /// Solo http/https: nunca se lanzan esquemas arbitrarios desde datos remotos.
  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(offer.affiliateUrl);
    var opened = false;

    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on PlatformException {
        opened = false;
      }
    }

    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo abrir ${offer.storeName}. Comprueba que tienes un navegador instalado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: offer.inStock ? 1 : 0.5,
      child: _RowShell(
        onTap: offer.inStock ? () => _open(context) : null,
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
