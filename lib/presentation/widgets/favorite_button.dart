import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../theme/app_colors.dart';

/// Corazón ligado a [favoritesProvider]. Solo se reconstruye con su propio SKU.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.sku, this.size = 22});

  final String sku;
  final double size;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(favoritesProvider.notifier).toggleFavorite(sku);
    } catch (_) {
      messenger?.showSnackBar(const SnackBar(content: Text('No se pudo guardar el favorito. Inténtalo de nuevo.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(isFavoriteProvider(sku));
    return IconButton(
      onPressed: () => _toggle(context, ref),
      tooltip: favorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
      isSelected: favorite,
      iconSize: size,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.favorite_border_rounded, color: AppColors.textSecondary),
      selectedIcon: const Icon(Icons.favorite_rounded, color: AppColors.error),
    );
  }
}
