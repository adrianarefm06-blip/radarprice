import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Menta "−25 %" si es chollo; naranja "+10 %" si está por encima de retail.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.savingsPercent});

  final double savingsPercent;

  static bool shouldShow(double? savingsPercent) =>
      savingsPercent != null && savingsPercent.abs() >= 1;

  @override
  Widget build(BuildContext context) {
    final isDeal = savingsPercent > 0;
    final percent = formatPercent(savingsPercent);
    return Semantics(
      label: isDeal ? '$percent de descuento' : '$percent por encima del precio de tienda',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: isDeal ? AppColors.deal : AppColors.premium,
            borderRadius: BorderRadius.circular(AppRadius.badge),
          ),
          child: Text(
            isDeal ? '−$percent' : '+$percent',
            style: AppTypography.price(
              fontSize: 14,
              color: isDeal ? AppColors.onDeal : AppColors.background,
            ),
          ),
        ),
      ),
    );
  }
}
