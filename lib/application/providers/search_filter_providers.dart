import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/sizes.dart';

/// Estado del buscador: segmento activo + talla dentro del segmento (`null` = Todas).
typedef SearchSizeFilter = ({SizeSegment segment, String? size});

/// Independiente de [selectedSizeFilterProvider]: las tallas del buscador
/// (niños, mujer) no deben alterar el filtro de Chollos ni del detalle.
class SearchSizeFilterNotifier extends Notifier<SearchSizeFilter> {
  @override
  SearchSizeFilter build() => (segment: SizeSegment.men, size: null);

  /// Conserva la talla si existe en el nuevo segmento (p. ej. 41 en Hombre y Mujer).
  void selectSegment(SizeSegment segment) {
    if (segment == state.segment) return;
    final current = state.size;
    state = (segment: segment, size: current != null && segment.sizes.contains(current) ? current : null);
  }

  void selectSize(String? size) {
    if (size != null && !state.segment.sizes.contains(size)) {
      throw ArgumentError.value(size, 'size', 'No pertenece al segmento ${state.segment.label}');
    }
    state = (segment: state.segment, size: size);
  }

  void toggleSize(String size) => selectSize(state.size == size ? null : size);
}

final searchSizeFilterProvider =
    NotifierProvider<SearchSizeFilterNotifier, SearchSizeFilter>(SearchSizeFilterNotifier.new);
