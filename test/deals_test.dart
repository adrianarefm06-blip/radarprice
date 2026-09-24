import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:radarprice/application/providers/providers.dart';
import 'package:radarprice/data/mock/in_memory_favorites_repository.dart';
import 'package:radarprice/data/mock/mock_alert_repository.dart';
import 'package:radarprice/data/mock/mock_product_repository.dart';
import 'package:radarprice/domain/models/models.dart';
import 'package:radarprice/domain/services/deal_comparison.dart';
import 'package:radarprice/presentation/router/app_router.dart';
import 'package:radarprice/presentation/screens/home_screen.dart';
import 'package:radarprice/presentation/screens/product_detail_screen.dart';
import 'package:radarprice/presentation/screens/store_deals_screen.dart';
import 'package:radarprice/presentation/widgets/deal_comparison_card.dart';
import 'package:radarprice/presentation/widgets/size_selector.dart';

StoreOffer _offer(String store, double price, {bool inStock = true}) => StoreOffer(
      storeName: store,
      storeLogoUrl: 'https://cdn.test/$store.png',
      price: price,
      inStock: inStock,
      affiliateUrl: 'https://$store.test/p',
    );

Product _product(
  String sku,
  Map<String, List<StoreOffer>> sizeOffers, {
  ProductGender gender = ProductGender.unisex,
  double retail = 100,
}) =>
    Product.fromOffers(
      id: 'prd_$sku',
      sku: sku,
      brand: 'Nike',
      model: 'Modelo $sku',
      imageUrl: 'https://cdn.test/$sku.webp',
      retailPrice: retail,
      sizeOffers: sizeOffers,
      colorway: 'White/Black',
      gender: gender,
    );

final _men = _product('MEN-1', {
  '42': [_offer('Nike', 100), _offer('Zalando', 79.95), _offer('StockX', 90, inStock: false)],
  '44': [_offer('Nike', 100, inStock: false), _offer('Zalando', 89.95)],
}, gender: ProductGender.men);

final _women = _product('WMN-1', {
  '38': [_offer('Nike', 60), _offer('Foot Locker', 60)],
  '42': [_offer('Nike', 95)],
}, gender: ProductGender.women);

final _unisex = _product('UNI-1', {
  '40': [_offer('StockX', 120)],
});

final _soldOut = _product('OUT-1', {
  '42': [_offer('Nike', 100, inStock: false)],
});

final _catalog = [_men, _women, _unisex, _soldOut];

/// Cuenta peticiones para comprobar que filtrar no vuelve a pedir datos.
class _CountingRepository extends MockProductRepository {
  _CountingRepository() : super(catalog: _catalog, latency: Duration.zero);

  int hotDealsCalls = 0;

  @override
  Future<List<Product>> getHotDeals() {
    hotDealsCalls++;
    return super.getHotDeals();
  }
}

void main() {
  group('buildDealComparison', () {
    test('talla concreta: tienda más barata marcada y sin stock al final', () {
      final deal = buildDealComparison(_men, size: '42')!;
      expect(deal.bestPrice, 79.95);
      expect(deal.maxSavingsPercent, closeTo(20.05, 0.001));
      expect([for (final q in deal.quotes) q.storeName], ['Zalando', 'Nike', 'StockX']);
      expect([for (final q in deal.quotes) q.isCheapest], [true, false, false]);
      expect(deal.quotes.last.inStock, isFalse);
      expect(deal.inStockCount, 2);
    });

    test('todas las tallas: mejor precio por tienda con su talla', () {
      final deal = buildDealComparison(_men)!;
      final nike = deal.quotes.firstWhere((q) => q.storeName == 'Nike');
      expect((nike.price, nike.size), (100.0, '42'));
      expect(deal.quotes.firstWhere((q) => q.storeName == 'StockX').inStock, isFalse);
    });

    test('empate de precio: ambas tiendas destacadas', () {
      final deal = buildDealComparison(_women, size: '38')!;
      expect(deal.quotes.every((q) => q.isCheapest), isTrue);
    });

    test('sin stock en la talla → null', () {
      expect(buildDealComparison(_men, size: '40'), isNull);
      expect(buildDealComparison(_soldOut), isNull);
    });
  });

  group('buildDealComparisons', () {
    test('ordenado por mayor descuento y sin productos agotados', () {
      final deals = buildDealComparisons(_catalog);
      expect([for (final d in deals) d.product.sku], ['WMN-1', 'MEN-1', 'UNI-1']);
    });

    test('segmentos: Hombre/Mujer incluyen unisex; Unisex solo unisex', () {
      List<String> skus(DealSegment s) => [for (final d in buildDealComparisons(_catalog, segment: s)) d.product.sku];
      expect(skus(DealSegment.men), ['MEN-1', 'UNI-1']);
      expect(skus(DealSegment.women), ['WMN-1', 'UNI-1']);
      expect(skus(DealSegment.unisex), ['UNI-1']);
    });

    test('tallas disponibles por segmento (solo con stock)', () {
      expect(availableDealSizes(_catalog), ['38', '40', '42', '44']);
      expect(availableDealSizes(_catalog, segment: DealSegment.women), ['38', '40', '42']);
    });
  });

  test('Product.fromJson: gender y colorway opcionales', () {
    final json = _men.toJson();
    expect(Product.fromJson(json), _men);
    final legacy = Map<String, dynamic>.of(json)
      ..remove('gender')
      ..remove('colorway');
    final parsed = Product.fromJson(legacy);
    expect((parsed.gender, parsed.colorway), (ProductGender.unisex, null));
  });

  group('filteredDealsProvider', () {
    late _CountingRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = _CountingRepository();
      container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(repository)]);
      addTearDown(container.dispose);
    });

    test('reacciona a talla y segmento sin volver a pedir datos', () async {
      container.listen(filteredDealsProvider, (_, __) {});
      await container.read(allDealsProvider.future);

      List<String> skus() => [for (final d in container.read(filteredDealsProvider).requireValue) d.product.sku];
      expect(skus(), ['WMN-1', 'MEN-1', 'UNI-1']);

      container.read(selectedSizeFilterProvider.notifier).select('42');
      expect(skus(), ['MEN-1', 'WMN-1']);

      container.read(dealSegmentProvider.notifier).select(DealSegment.women);
      expect(skus(), ['WMN-1']);
      expect(container.read(dealSizesProvider), ['38', '40', '42']);

      container.read(selectedSizeFilterProvider.notifier).select('44');
      expect(skus(), isEmpty);

      expect(repository.hotDealsCalls, 1);
    });

    test('acepta tallas de la API fuera de las listas fijas', () {
      container.read(selectedSizeFilterProvider.notifier).select('47.5');
      expect(container.read(selectedSizeFilterProvider), '47.5');
      expect(() => container.read(selectedSizeFilterProvider.notifier).select('XL'), throwsArgumentError);
    });
  });

  group('UI', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    Finder sizeChip(String size) =>
        find.descendant(of: find.byType(SizeChipsBar), matching: find.text('EU $size'));

    void tallViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Widget app(Widget home) => ProviderScope(
          overrides: [
            productRepositoryProvider.overrideWithValue(MockProductRepository(catalog: _catalog, latency: Duration.zero)),
            alertRepositoryProvider.overrideWithValue(MockAlertRepository(latency: Duration.zero)),
            favoritesRepositoryProvider.overrideWithValue(InMemoryFavoritesRepository()),
          ],
          child: MaterialApp(
            home: Scaffold(body: home),
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        );

    testWidgets('Home: chollos con filtros, estado vacío por talla y vista por tiendas', (tester) async {
      tallViewport(tester);
      await tester.pumpWidget(app(const HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(DealComparisonCard), findsNWidgets(3));
      expect(sizeChip('44'), findsOneWidget);

      await tester.tap(find.text('Mujer'));
      await tester.pumpAndSettle();
      expect(find.byType(DealComparisonCard), findsNWidgets(2));
      expect(sizeChip('44'), findsNothing);

      await tester.tap(sizeChip('40'));
      await tester.pumpAndSettle();
      expect(find.byType(DealComparisonCard), findsOneWidget);

      await tester.tap(find.text('Hombre'));
      await tester.tap(sizeChip('40'));
      await tester.pumpAndSettle();
      await tester.tap(sizeChip('44'));
      await tester.pumpAndSettle();
      expect(find.byType(DealComparisonCard), findsOneWidget);

      await tester.tap(find.text('Unisex'));
      await tester.pumpAndSettle();
      expect(find.text('No hay ofertas en stock para la talla 44'), findsOneWidget);

      await tester.tap(find.text('Por tienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zalando').first);
      await tester.pumpAndSettle();
      expect(find.byType(StoreDealsScreen), findsOneWidget);
    });

    testWidgets('Detalle: tallas reales del producto', (tester) async {
      tallViewport(tester);
      await tester.pumpWidget(app(ProductDetailScreen(sku: _women.sku, initialProduct: _women)));
      await tester.pumpAndSettle();
      expect(find.text('EU 38'), findsWidgets);
      expect(find.text('EU 42'), findsWidgets);
      expect(find.text('EU 43'), findsNothing);
      expect(find.text('Agotado temporalmente'), findsNothing);
    });

    testWidgets('Detalle: sin tallas en stock → Agotado temporalmente', (tester) async {
      tallViewport(tester);
      await tester.pumpWidget(app(ProductDetailScreen(sku: _soldOut.sku, initialProduct: _soldOut)));
      await tester.pumpAndSettle();
      expect(find.text('Agotado temporalmente'), findsOneWidget);
      expect(find.text('Tu talla'), findsNothing);
    });
  });
}
