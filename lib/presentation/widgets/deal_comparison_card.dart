import 'package:flutter/material.dart';

import '../../domain/services/deal_comparison.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'discount_badge.dart';
import 'product_card.dart';
import 'sneaker_image.dart';
import 'store_logo.dart';

/// Tarjeta del feed "Mejores chollos": descuento máximo + comparador de tiendas.
/// Presentacional (sin Riverpod): recibe la comparación ya calculada.
class DealComparisonCard extends StatelessWidget {
  const DealComparisonCard({super.key, required this.deal, this.onTap, this.onQuoteTap, this.action});

  final DealComparison deal;
  final VoidCallback? onTap;

  /// Tap sobre una tienda con stock (p. ej. abrir su web).
  final ValueChanged<StoreQuote>? onQuoteTap;

  /// Acción en la esquina superior derecha (p. ej. botón de favorito).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final product = deal.product;
    final text = Theme.of(context).textTheme;
    final colorway = product.colorway;
    final showRetail = (deal.bestPrice - product.retailPrice).abs() >= 0.01;
    final action = this.action;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ImageTile(deal: deal),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.brand,
                                style: text.labelLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ?action,
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(product.model, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (colorway != null && colorway.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            colorway,
                            style: text.bodySmall?.copyWith(color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: 8,
                          children: [
                            Text(
                              deal.size == null ? 'desde ${formatPrice(deal.bestPrice)}' : formatPrice(deal.bestPrice),
                              style: AppTypography.price(fontSize: 22),
                            ),
                            if (showRetail)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  formatPrice(product.retailPrice),
                                  style: text.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: AppColors.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                deal.size == null ? 'Mejor precio por tienda (cualquier talla)' : 'Tiendas con la EU ${deal.size}',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final quote in deal.quotes)
                    _QuoteChip(
                      key: ValueKey(quote.storeName),
                      quote: quote,
                      showSize: deal.size == null,
                      onTap: quote.inStock && onQuoteTap != null ? () => onQuoteTap!(quote) : null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.deal});

  final DealComparison deal;

  @override
  Widget build(BuildContext context) {
    final product = deal.product;
    return SizedBox.square(
      dimension: 104,
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
          if (DiscountBadge.shouldShow(deal.maxSavingsPercent))
            Positioned(top: 6, left: 6, child: DiscountBadge(savingsPercent: deal.maxSavingsPercent)),
        ],
      ),
    );
  }
}

/// Tienda + precio. Más barata → menta; sin stock → atenuada y no pulsable.
class _QuoteChip extends StatelessWidget {
  const _QuoteChip({super.key, required this.quote, required this.showSize, this.onTap});

  final StoreQuote quote;
  final bool showSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final price = quote.price;
    final cheapest = quote.isCheapest;
    final size = quote.size;
    final simulated = quote.offer?.isSimulated ?? false;
    final text = Theme.of(context).textTheme;

    final label = price == null
        ? '${quote.storeName}: sin stock'
        : '${quote.storeName}: ${formatPrice(price)}${simulated ? ' estimado' : ''}'
            '${showSize && size != null ? ', talla EU $size' : ''}'
            '${cheapest ? ', mejor precio' : ''}';

    return Semantics(
      button: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: quote.inStock ? 1 : 0.4,
          child: Material(
            color: cheapest ? AppColors.deal.withValues(alpha: 0.12) : AppColors.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              side: BorderSide(color: cheapest ? AppColors.deal : AppColors.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StoreLogo(logoUrl: quote.storeLogoUrl, storeName: quote.storeName, size: 18),
                    const SizedBox(width: 6),
                    Text(quote.storeName, style: text.labelMedium?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    if (price == null)
                      Text(
                        'Agotado',
                        style: text.labelMedium?.copyWith(
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.textMuted,
                        ),
                      )
                    else ...[
                      Text(
                        formatPrice(price),
                        style: AppTypography.price(
                          fontSize: 15,
                          color: cheapest ? AppColors.deal : AppColors.textPrimary,
                        ),
                      ),
                      if (showSize && size != null) ...[
                        const SizedBox(width: 4),
                        Text('EU $size', style: text.labelSmall?.copyWith(color: AppColors.textMuted)),
                      ],
                      if (simulated) ...[
                        const SizedBox(width: 4),
                        const EstimatedTag(),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marca de precio de demostración (oferta `simulated`): nunca se presenta como real.
class EstimatedTag extends StatelessWidget {
  const EstimatedTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Precio estimado (dato de demostración, no leído de la tienda)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.badge),
          border: Border.all(color: AppColors.textMuted),
        ),
        child: Text(
          'Est.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
