import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'shimmer.dart';

/// Foto de producto con shimmer de carga y monograma de marca si falla.
/// Pensada para ir sobre un fondo [AppColors.imageTile].
class SneakerImage extends StatelessWidget {
  const SneakerImage({super.key, required this.imageUrl, required this.brand});

  final String imageUrl;
  final String brand;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      semanticLabel: 'Foto de $brand',
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Shimmer(
              baseColor: AppColors.imageTile,
              highlightColor: AppColors.imageTileShimmer,
              child: SizedBox.expand(child: ShimmerBox()),
            ),
      errorBuilder: (context, error, stackTrace) => _BrandMonogram(brand: brand),
    );
  }
}

class _BrandMonogram extends StatelessWidget {
  const _BrandMonogram({required this.brand});

  final String brand;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: FittedBox(
          child: Text(
            brand,
            style: GoogleFonts.archivoNarrow(
              fontWeight: FontWeight.w800,
              fontSize: 28,
              letterSpacing: -0.5,
              color: AppColors.imageTileMonogram,
            ),
          ),
        ),
      ),
    );
  }
}
