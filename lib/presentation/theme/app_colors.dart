import 'package:flutter/material.dart';

/// Paleta RadarPrice. Regla: el menta solo significa "ahorro";
/// el naranja solo significa "por encima de retail". Nada más usa esos colores.
abstract final class AppColors {
  static const background = Color(0xFF0F0F11);
  static const surface = Color(0xFF1A1A1E);
  static const surfaceRaised = Color(0xFF24242A);
  static const outline = Color(0xFF2E2E35);

  static const textPrimary = Color(0xFFF2F2F3);
  static const textSecondary = Color(0xFF9B9BA4);
  static const textMuted = Color(0xFF63636C);

  static const deal = Color(0xFF3DF5B0);
  static const onDeal = Color(0xFF05140E);
  static const premium = Color(0xFFFF7A2F);
  static const error = Color(0xFFFF5A5F);

  /// Fondo claro de las fotos de producto (packshots sobre blanco).
  static const imageTile = Color(0xFFE9E9EC);
  static const imageTileShimmer = Color(0xFFF6F6F8);
  static const imageTileMonogram = Color(0xFFC8C8CE);
}
