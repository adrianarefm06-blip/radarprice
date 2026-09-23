import 'package:flutter/material.dart';

import '../../domain/services/store_catalog.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'shimmer.dart';
import 'store_logo.dart';

class StoreCard extends StatefulWidget {
  const StoreCard({super.key, required this.summary, this.onTap});

  final StoreSummary summary;
  final VoidCallback? onTap;

  static String offerCountLabel(int count) => switch (count) {
        0 => 'Sin stock ahora',
        1 => '1 oferta activa',
        _ => '$count ofertas activas',
      };

  @override
  State<StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<StoreCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final text = Theme.of(context).textTheme;
    final best = s.bestSavingsPercent;
    final countLabel = StoreCard.offerCountLabel(s.activeOfferCount);
    final dealLabel = s.hasDeal && best != null ? '−${formatPercent(best)}' : '—';

    return Semantics(
      button: widget.onTap != null,
      excludeSemantics: true,
      label: '${s.storeName}, $countLabel, '
          '${s.hasDeal && best != null ? 'hasta ${formatPercent(best)} de descuento' : 'sin descuentos'}',
      child: AnimatedScale(
        scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? 0.97 : 1,
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StoreLogo(logoUrl: s.storeLogoUrl, storeName: s.storeName, size: 36),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
                    ],
                  ),
                  const Spacer(),
                  Text(s.storeName, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(countLabel, style: text.bodySmall),
                  const SizedBox(height: 12),
                  Text(
                    s.hasDeal ? 'Mejor descuento' : 'Sin descuentos ahora',
                    style: text.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dealLabel,
                    style: AppTypography.price(
                      fontSize: 28,
                      color: s.hasDeal ? AppColors.deal : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StoreCardSkeleton extends StatelessWidget {
  const StoreCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 36, height: 36, radius: 18),
            Spacer(),
            ShimmerBox(width: 84, height: 16),
            SizedBox(height: 6),
            ShimmerBox(width: 104, height: 12),
            SizedBox(height: 14),
            ShimmerBox(width: 72, height: 12),
            SizedBox(height: 6),
            ShimmerBox(width: 64, height: 26),
          ],
        ),
      ),
    );
  }
}
