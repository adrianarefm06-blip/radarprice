import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'shimmer.dart';
import 'state_views.dart';

/// Histórico de precio mínimo con selector 30d / 90d.
/// Muestra el retail como referencia discontinua y un tooltip con fecha y precio.
class PriceHistoryChart extends ConsumerStatefulWidget {
  const PriceHistoryChart({super.key, required this.product, this.chartHeight = 180});

  final Product product;
  final double chartHeight;

  static const ranges = [30, 90];

  @override
  ConsumerState<PriceHistoryChart> createState() => _PriceHistoryChartState();
}

class _PriceHistoryChartState extends ConsumerState<PriceHistoryChart> {
  int _days = PriceHistoryChart.ranges.last;

  /// Serie anterior visible mientras carga el nuevo rango (sin parpadeo).
  List<PricePoint>? _lastPoints;

  PriceHistoryParams get _params => (sku: widget.product.sku, days: _days);

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(priceHistoryProvider(_params));
    if (history.hasValue) _lastPoints = history.requireValue;
    final points = _lastPoints;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Evolución del precio', style: text.titleSmall)),
            _RangeToggle(
              ranges: PriceHistoryChart.ranges,
              selected: _days,
              onChanged: (days) => setState(() => _days = days),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (history.hasError && !history.isLoading)
          SizedBox(
            height: widget.chartHeight + 60,
            child: ErrorStateView(
              error: history.error!,
              onRetry: () => ref.invalidate(priceHistoryProvider(_params)),
            ),
          )
        else if (points == null || points.length < 2)
          _ChartSkeleton(height: widget.chartHeight)
        else
          AnimatedOpacity(
            opacity: history.isLoading ? 0.5 : 1,
            duration: const Duration(milliseconds: 150),
            child: _ChartContent(
              points: points,
              retailPrice: widget.product.retailPrice,
              days: _days,
              height: widget.chartHeight,
            ),
          ),
      ],
    );
  }
}

class _ChartContent extends StatelessWidget {
  const _ChartContent({
    required this.points,
    required this.retailPrice,
    required this.days,
    required this.height,
  });

  final List<PricePoint> points;
  final double retailPrice;
  final int days;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final prices = points.map((p) => p.price);
    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);

    // El rango vertical incluye el retail para que la referencia siempre se vea.
    final low = math.min(minPrice, retailPrice);
    final high = math.max(maxPrice, retailPrice);
    final span = math.max(high - low, 1.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Stat(label: 'Mínimo en $days días', value: formatPrice(minPrice), highlight: true),
            const SizedBox(width: 24),
            _Stat(label: 'Máximo en $days días', value: formatPrice(maxPrice)),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Gráfica de precio de los últimos $days días. '
              'Mínimo ${formatPrice(minPrice)}, máximo ${formatPrice(maxPrice)}, '
              'actual ${formatPrice(points.last.price)}.',
          child: SizedBox(
            height: height,
            child: LineChart(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: low - span * 0.15,
                maxY: high + span * 0.12,
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: span / 3,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.outline, strokeWidth: 0.5),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: retailPrice,
                      color: AppColors.textMuted,
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topLeft,
                        padding: const EdgeInsets.only(left: 2, bottom: 4),
                        style: text.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 11),
                        labelResolver: (_) => 'Precio de tienda ${formatPrice(retailPrice)}',
                      ),
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (barData, indexes) => [
                    for (final _ in indexes)
                      TouchedSpotIndicatorData(
                        const FlLine(color: AppColors.textMuted, strokeWidth: 1, dashArray: [3, 3]),
                        FlDotData(
                          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                            radius: 4.5,
                            color: AppColors.deal,
                            strokeWidth: 2.5,
                            strokeColor: AppColors.background,
                          ),
                        ),
                      ),
                  ],
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceRaised,
                    tooltipRoundedRadius: 10,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    tooltipMargin: 12,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => [
                      for (final spot in spots)
                        LineTooltipItem(
                          '${formatPrice(spot.y)}\n',
                          AppTypography.price(fontSize: 17),
                          children: [
                            TextSpan(
                              text: formatShortDate(points[spot.x.round()].date, withYear: true),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].price),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.18,
                    preventCurveOverShooting: true,
                    color: AppColors.deal,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.deal.withValues(alpha: 0.22),
                          AppColors.deal.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatShortDate(points.first.date), style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
            Text('Hoy', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.price(
            fontSize: 20,
            color: highlight ? AppColors.deal : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.ranges, required this.selected, required this.onChanged});

  final List<int> ranges;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final days in ranges)
            Semantics(
              button: true,
              selected: days == selected,
              label: 'Últimos $days días',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (days != selected) onChanged(days);
                },
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: days == selected ? AppColors.textPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.control - 3),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      '${days}d',
                      style: AppTypography.price(
                        fontSize: 14,
                        color: days == selected ? AppColors.background : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              ShimmerBox(width: 90, height: 34),
              SizedBox(width: 24),
              ShimmerBox(width: 90, height: 34),
            ],
          ),
          const SizedBox(height: 16),
          ShimmerBox(height: height, radius: AppRadius.tile),
          const SizedBox(height: 8),
          const ShimmerBox(width: 120, height: 12),
        ],
      ),
    );
  }
}
