import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StoreLogo extends StatelessWidget {
  const StoreLogo({super.key, required this.logoUrl, required this.storeName, this.size = 20});

  final String logoUrl;
  final String storeName;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Image.network(
          logoUrl,
          fit: BoxFit.cover,
          semanticLabel: storeName,
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: AppColors.surfaceRaised,
            child: Center(
              child: Text(
                storeName.isEmpty ? '?' : storeName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
