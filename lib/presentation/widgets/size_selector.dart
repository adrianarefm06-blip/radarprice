import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../core/constants/sizes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Chips horizontales de talla EU. Estado global: la talla del usuario se
/// comparte entre Chollos, Búsqueda y Detalle.
class SizeSelector extends ConsumerWidget {
  const SizeSelector({super.key, this.padding = const EdgeInsets.symmetric(horizontal: 20)});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedSizeFilterProvider);
    final notifier = ref.read(selectedSizeFilterProvider.notifier);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: kSupportedSizes.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SizeChip(label: 'Todas', selected: selected == null, onTap: notifier.clear);
          }
          final size = kSupportedSizes[index - 1];
          return _SizeChip(
            label: 'EU $size',
            selected: selected == size,
            onTap: () => notifier.toggle(size),
          );
        },
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180);

    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.textPrimary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: selected ? AppColors.textPrimary : AppColors.outline),
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            style: AppTypography.price(
              fontSize: 15,
              color: selected ? AppColors.background : AppColors.textSecondary,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
