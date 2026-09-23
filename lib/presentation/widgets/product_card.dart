import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'discount_badge.dart';
import 'price_line.dart';
import 'product_pricing.dart';
import 'sneaker_image.dart';
import 'store_logo.dart';

/// Tarjeta de feed. Sin dependencias de Riverpod: recibe todo por parámetros
/// para poder reutilizarse en Chollos, Búsqueda y futuras listas.
class ProductCard extends StatefulWidget {
  const ProductCard({super.key, required this.product, this.selectedSize, this.onTap});

  final Product product;
  final String? selectedSize;
  final VoidCallback? onTap;

  /// Tag compartido con la imagen del detalle.
  static Object heroTagFor(String sku) => 'product-image-$sku';

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final pricing = ProductPricing.of(product, widget.selectedSize);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedScale(
      scale: _pressed && !reduceMotion ? 0.98 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ImageTile(product: product, pricing: pricing),
                const SizedBox(width: 14),
                Expanded(child: _Details(product: product, pricing: pricing)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.product, required this.pricing});

  final Product product;
  final ProductPricing pricing;

  @override
  Widget build(BuildContext context) {
    final savings = pricing.savingsPercent;
    return SizedBox.square(
      dimension: 116,
      child: Stack(
        children: [
          Positioned.fill(
            child: Hero(
              tag: ProductCard.heroTagFor(product.sku),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                child: ColoredBox(
                  color: AppColors.imageTile,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SneakerImage(imageUrl: product.imageUrl, brand: product.brand),
                  ),
                ),
              ),
            ),
          ),
          if (savings != null && DiscountBadge.shouldShow(savings))
            Positioned(top: 6, left: 6, child: DiscountBadge(savingsPercent: savings)),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.product, required this.pricing});

  final Product product;
  final ProductPricing pricing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final offer = pricing.bestOffer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Text(product.brand, style: text.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(product.model, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        PriceLine(pricing: pricing),
        if (offer != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              StoreLogo(logoUrl: offer.storeLogoUrl, storeName: offer.storeName, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pricing.selectedSize != null
                      ? 'Mejor precio en ${offer.storeName}'
                      : 'Mejor precio en ${offer.storeName}, talla EU ${pricing.offerSize}',
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
