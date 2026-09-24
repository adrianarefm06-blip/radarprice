import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'estimated_tag.dart';
import 'product_pricing.dart';

/// Precio actual (menta si es chollo) + retail tachado como referencia.
/// Si la mejor oferta es de demostración, añade la etiqueta "Est.": nunca se presenta como real.
class PriceLine extends StatelessWidget {
  const PriceLine({super.key, required this.pricing, this.priceFontSize = 26});

  final ProductPricing pricing;
  final double priceFontSize;

  @override
  Widget build(BuildContext context) {
    final price = pricing.price;
    if (price == null) {
      return Text(
        pricing.selectedSize == null ? 'Agotado en todas las tallas' : 'Agotado en EU ${pricing.selectedSize}',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formatPrice(price),
          style: AppTypography.price(
            fontSize: priceFontSize,
            color: pricing.isDeal ? AppColors.deal : AppColors.textPrimary,
          ),
        ),
        if (pricing.bestOffer?.isSimulated ?? false) ...[
          const SizedBox(width: 8),
          const EstimatedTag(),
        ],
        if (pricing.showsRetailReference) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              formatPrice(pricing.retailPrice),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              semanticsLabel: 'Precio de tienda ${formatPrice(pricing.retailPrice)}',
              style: AppTypography.price(fontSize: priceFontSize * 0.58, color: AppColors.textMuted).copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
