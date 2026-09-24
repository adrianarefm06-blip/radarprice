import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:radarprice/application/providers/providers.dart';
import 'package:radarprice/data/mock/in_memory_favorites_repository.dart';
import 'package:radarprice/data/mock/mock_product_repository.dart';
import 'package:radarprice/domain/models/models.dart';
import 'package:radarprice/presentation/widgets/price_history_chart.dart';

final _product = Product.fromOffers(
  id: 'prd_x',
  sku: 'SKU-1',
  brand: 'Nike',
  model: 'Dunk',
  imageUrl: 'https://cdn.test/x.webp',
  retailPrice: 120,
  sizeOffers: {
    '42': [
      const StoreOffer(
        storeName: 'Zalando',
        storeLogoUrl: 'https://cdn.test/z.png',
        price: 90,
        inStock: true,
        affiliateUrl: 'https://z.test',
      ),
    ],
  },
);

PricePoint _p(int day, double price) => PricePoint(date: DateTime(2026, 9, day), price: price);

/// Histórico controlado por el test; registra los rangos pedidos.
class _HistoryRepository extends MockProductRepository {
  _HistoryRepository(this.byDays) : super(catalog: [_product], latency: Duration.zero);

  final Map<int, List<PricePoint>> byDays;
  final requested = <int>[];

  @override
  Future<List<PricePoint>> getPriceHistory(String sku, {int days = 90}) async {
    requested.add(days);
    return byDays[days] ?? const [];
  }
}

Future<_HistoryRepository> _pump(WidgetTester tester, Map<int, List<PricePoint>> byDays) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final repository = _HistoryRepository(byDays);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      productRepositoryProvider.overrideWithValue(repository),
      favoritesRepositoryProvider.overrideWithValue(InMemoryFavoritesRepository()),
    ],
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: PriceHistoryChart(product: _product))),
    ),
  ));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  test('lowestPricePoint: mínimo y, en empate, el más reciente', () {
    expect(lowestPricePoint(const []), isNull);
    expect(lowestPricePoint([_p(1, 100), _p(2, 80), _p(3, 80), _p(4, 95)]), _p(3, 80));
  });

  testWidgets('30 días por defecto y mínimo histórico de la serie larga', (tester) async {
    final repository = await _pump(tester, {
      30: [_p(20, 110), _p(21, 95), _p(22, 99)],
      365: [_p(1, 75), _p(20, 110), _p(21, 95), _p(22, 99)],
    });
    expect(repository.requested, containsAll([30, 365]));
    expect(repository.requested, isNot(contains(90)));
    expect(find.text('Historial de precios'), findsOneWidget);
    expect(find.text('Mínimo histórico'), findsOneWidget);
    expect(find.textContaining('75'), findsWidgets); // histórico fuera de la ventana
  });

  testWidgets('menos de 2 puntos → placeholder', (tester) async {
    await _pump(tester, {
      30: [_p(22, 99)],
      365: [_p(22, 99)],
    });
    expect(find.text('Historial acumulándose con cada sincronización'), findsOneWidget);
    expect(find.text('Mínimo histórico'), findsNothing);
  });
}
