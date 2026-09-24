import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Marca de precio de demostración (oferta `simulated`): nunca se presenta como real.
class EstimatedTag extends StatelessWidget {
  const EstimatedTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Precio estimado (dato de demostración, no leído de la tienda)',
      excludeFromSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.badge),
          border: Border.all(color: AppColors.textMuted),
        ),
        child: Text(
          'Est.',
          semanticsLabel: 'precio estimado',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
