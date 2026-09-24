import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Talla EU activa del usuario en Chollos / tienda / detalle. `null` = todas.
class SelectedSizeFilter extends Notifier<String?> {
  @override
  String? build() => null;

  /// Acepta cualquier talla EU numérica (las tallas reales vienen de la API).
  void select(String? size) {
    if (size != null && !_euSize.hasMatch(size)) {
      throw ArgumentError.value(size, 'size', 'Talla no soportada');
    }
    state = size;
  }

  static final _euSize = RegExp(r'^\d{1,2}([.,]\d)?$');

  /// Tap sobre el chip activo lo deselecciona.
  void toggle(String size) => select(state == size ? null : size);

  void clear() => state = null;
}

final selectedSizeFilterProvider =
    NotifierProvider<SelectedSizeFilter, String?>(SelectedSizeFilter.new);
