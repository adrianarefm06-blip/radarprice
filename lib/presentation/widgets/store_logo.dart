import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StoreLogo extends StatelessWidget {
  const StoreLogo({super.key, required this.logoUrl, required this.storeName, this.size = 20});

  final String logoUrl;
  final String storeName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = ColoredBox(
      color: AppColors.surfaceRaised,
      child: Center(
        child: Text(
          storeName.isEmpty ? '?' : storeName.substring(0, 1).toUpperCase(),
          style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
      ),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        // Sin logo alojado (la API devuelve ""): inicial de la tienda sin petición de red.
        child: logoUrl.startsWith('https://')
            ? Image.network(
                logoUrl,
                fit: BoxFit.cover,
                semanticLabel: storeName,
                errorBuilder: (context, error, stackTrace) => initial,
              )
            : Semantics(label: storeName, child: initial),
      ),
    );
  }
}
