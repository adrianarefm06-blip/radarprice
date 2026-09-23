import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/sizes.dart';

/// Talla EU activa del usuario en Chollos / tienda / detalle. `null` = todas.
class SelectedSizeFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? size) {
    if (size != null && !kAllSizes.contains(size)) {
      throw ArgumentError.value(size, 'size', 'Talla no soportada');
    }
    state = size;
  }

  /// Tap sobre el chip activo lo deselecciona.
  void toggle(String size) => select(state == size ? null : size);

  void clear() => state = null;
}

final selectedSizeFilterProvider =
    NotifierProvider<SelectedSizeFilter, String?>(SelectedSizeFilter.new);
