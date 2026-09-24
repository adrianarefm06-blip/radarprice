import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Chips ligados a [selectedSizeFilterProvider] (Chollos, tienda y detalle).
/// [sizes] siempre sale de los datos reales (API), nunca de una lista fija.
class SizeSelector extends ConsumerWidget {
  const SizeSelector({
    super.key,
    required this.sizes,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<String> sizes;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectedSizeFilterProvider.notifier);
    return SizeChipsBar(
      sizes: sizes,
      selected: ref.watch(selectedSizeFilterProvider),
      padding: padding,
      onSelected: (size) => size == null ? notifier.clear() : notifier.toggle(size),
    );
  }
}

/// Fila horizontal "Todas" + tallas. Presentacional: el estado lo decide el padre.
/// `onSelected(null)` = "Todas"; `onSelected(size)` = tap sobre esa talla.
class SizeChipsBar extends StatelessWidget {
  const SizeChipsBar({
    super.key,
    required this.sizes,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.allLabel = 'Todas',
  });

  final List<String> sizes;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final EdgeInsets padding;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Clave por rango: al cambiar de segmento, el scroll vuelve al inicio con fundido.
    final rangeKey = ValueKey(sizes.join('|'));

    return SizedBox(
      height: 40,
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
        child: ListView.separated(
          key: rangeKey,
          scrollDirection: Axis.horizontal,
          padding: padding,
          itemCount: sizes.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) => index == 0
              ? _SizeChip(label: allLabel, selected: selected == null, onTap: () => onSelected(null))
              : _SizeChip(
                  label: 'EU ${sizes[index - 1]}',
                  selected: selected == sizes[index - 1],
                  onTap: () => onSelected(sizes[index - 1]),
                ),
        ),
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
