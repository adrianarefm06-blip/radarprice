import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'shimmer.dart';

/// Foto de producto (de la tienda real, con caché en disco) con shimmer de carga
/// y monograma de marca si no hay foto o falla. Pensada para ir sobre [AppColors.imageTile].
class SneakerImage extends StatelessWidget {
  const SneakerImage({super.key, required this.imageUrl, required this.brand});

  final String imageUrl;
  final String brand;

  /// Tests de widgets: la caché en disco necesita canales de plataforma que allí no existen
  /// (ver test/flutter_test_config.dart). Con false se usa [Image.network] sin caché en disco.
  @visibleForTesting
  static bool diskCache = true;

  @override
  Widget build(BuildContext context) {
    // Sin foto (la API devuelve "" hasta que una tienda real la aporta): monograma directo.
    if (!imageUrl.startsWith('https://')) return _BrandMonogram(brand: brand);
    if (!diskCache) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        semanticLabel: 'Foto de $brand',
        errorBuilder: (context, error, stackTrace) => _BrandMonogram(brand: brand),
      );
    }
    return Semantics(
      image: true,
      label: 'Foto de $brand',
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        // Decodifica a tamaño de pantalla, no al original (fotos de hasta ~1000 px).
        memCacheWidth: 600,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => const Shimmer(
          baseColor: AppColors.imageTile,
          highlightColor: AppColors.imageTileShimmer,
          child: SizedBox.expand(child: ShimmerBox()),
        ),
        errorWidget: (context, url, error) => _BrandMonogram(brand: brand),
      ),
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
