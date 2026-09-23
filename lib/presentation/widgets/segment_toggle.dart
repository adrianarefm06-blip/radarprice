import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Control segmentado a ancho completo (mismo lenguaje que los chips de talla).
class SegmentToggle<T> extends StatelessWidget {
  const SegmentToggle({
    super.key,
    required this.segments,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> segments;
  final T selected;
  final String Function(T segment) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180);
    final textStyle = Theme.of(context).textTheme.labelLarge;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: segment == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (segment == selected) return;
                    HapticFeedback.selectionClick();
                    onChanged(segment);
                  },
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOut,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: segment == selected ? AppColors.textPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.control - 3),
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      style: (textStyle ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.w600,
                        color: segment == selected ? AppColors.background : AppColors.textSecondary,
                      ),
                      child: Text(labelOf(segment)),
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
