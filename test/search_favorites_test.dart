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
import 'package:radarprice/infrastructure/repositories/shared_prefs_favorites_repository.dart';
import 'package:radarprice/presentation/router/app_router.dart';
import 'package:radarprice/presentation/screens/home_screen.dart';
import 'package:radarprice/presentation/widgets/deal_comparison_card.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

StoreOffer _offer(String store, double price) => StoreOffer(
      storeName: store,
      storeLogoUrl: 'https://cdn.test/$store.png',
      price: price,
      inStock: true,
      affiliateUrl: 'https://$store.test/p',
    );

Product _product(String sku, String brand, String model, String colorway, double price, {double retail = 100}) =>
    Product.fromOffers(
      id: 'prd_$sku',
      sku: sku,
      brand: brand,
      model: model,
      imageUrl: 'https://cdn.test/$sku.webp',
      retailPrice: retail,
      colorway: colorway,
      sizeOffers: {
        '42': [_offer('Zalando', price)],
      },
    );

// Descuentos: panda 30 %, samba 10 %, campus 20 % (precio 160 sobre retail 200).
final _panda = _product('HF5441-100', 'Nike', 'Dunk Low "Panda"', 'White/Black', 70);
final _samba = _product('B75806', 'adidas', 'Samba OG', 'Cloud White/Gum', 90);
final _campus = _product('HQ8708', 'adidas', 'Campus 00s', 'Core Black', 160, retail: 200);
final _catalog = [_panda, _samba, _campus];

class _CountingRepository extends MockProductRepository {
  _CountingRepository() : super(catalog: _catalog, latency: Duration.zero);

  int calls = 0;

  @override
  Future<List<Product>> getCatalog() {
    calls++;
    return super.getCatalog();
  }
}

List<String> _skus(Iterable<DealComparison> deals) => [for (final d in deals) d.product.sku];

void main() {
  group('matchesDealQuery', () {
    test('marca, modelo, colorway y SKU; sin mayúsculas ni tildes', () {
      expect(matchesDealQuery(_panda, 'NIKE panda'), isTrue);
      expect(matchesDealQuery(_panda, 'black'), isTrue);
      expect(matchesDealQuery(_panda, 'hf5441100'), isTrue);
      expect(matchesDealQuery(_panda, 'HF5441-100'), isTrue);
      expect(matchesDealQuery(_samba, 'sámba'), isTrue);
      expect(matchesDealQuery(_samba, 'samba panda'), isFalse);
      expect(matchesDealQuery(_samba, '   '), isTrue);
    });
  });

  group('refineDeals', () {
    final deals = buildDealComparisons(_catalog);

    test('orden: descuento, precio, nombre', () {
      expect(_skus(refineDeals(deals)), ['HF5441-100', 'HQ8708', 'B75806']);
      expect(_skus(refineDeals(deals, sort: DealSort.price)), ['HF5441-100', 'B75806', 'HQ8708']);
      expect(_skus(refineDeals(deals, sort: DealSort.name)), ['HQ8708', 'B75806', 'HF5441-100']);
    });

    test('texto y SKUs permitidos se combinan', () {
      expect(_skus(refineDeals(deals, query: 'adidas')), ['HQ8708', 'B75806']);
      expect(_skus(refineDeals(deals, query: 'adidas', onlySkus: {'B75806', 'HF5441-100'})), ['B75806']);
      expect(refineDeals(deals, onlySkus: const {}), isEmpty);
    });
  });

  group('SharedPrefsFavoritesRepository', () {
    setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

    test('persiste y recarga el conjunto', () async {
      final repository = SharedPrefsFavoritesRepository();
      expect(await repository.load(), isEmpty);
      await repository.save({'B75806', 'HF5441-100'});
      expect(await SharedPrefsFavoritesRepository().load(), {'B75806', 'HF5441-100'});
    });
  });

  group('Providers', () {
    late _CountingRepository products;
    late InMemoryFavoritesRepository favorites;
    late ProviderContainer container;

    setUp(() {
      products = _CountingRepository();
      favorites = InMemoryFavoritesRepository({'B75806'});
      container = ProviderContainer(overrides: [
        productRepositoryProvider.overrideWithValue(products),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ]);
      addTearDown(container.dispose);
    });

    test('favoritos: carga, toggle persistente y rollback si falla', () async {
      expect(await container.read(favoritesProvider.future), {'B75806'});

      expect(await container.read(favoritesProvider.notifier).toggleFavorite('HQ8708'), isTrue);
      expect(favorites.stored, {'B75806', 'HQ8708'});
      expect(container.read(isFavoriteProvider('HQ8708')), isTrue);

      favorites.failWrites = true;
      await expectLater(container.read(favoritesProvider.notifier).toggleFavorite('B75806'), throwsStateError);
      expect(container.read(favoritesProvider).value, {'B75806', 'HQ8708'});
    });

    test('debounce de 300 ms y filtros sin volver a pedir datos', () async {
      container.listen(filteredDealsProvider, (_, __) {});
      await container.read(allDealsProvider.future);
      await container.read(favoritesProvider.future);
      List<String> visible() => _skus(container.read(filteredDealsProvider).requireValue);

      final query = container.read(dealQueryProvider.notifier)..setQuery('adi');
      query.setQuery('adidas');
      expect(container.read(dealQueryProvider), isEmpty, reason: 'aún dentro del debounce');
      await Future<void>.delayed(DealQuery.debounce + const Duration(milliseconds: 50));
      expect(container.read(dealQueryProvider), 'adidas');
      expect(visible(), ['HQ8708', 'B75806']);

      container.read(dealSortProvider.notifier).select(DealSort.price);
      expect(visible(), ['B75806', 'HQ8708']);

      container.read(favoritesOnlyProvider.notifier).toggle();
      expect(visible(), ['B75806']);

      query.setQuery('');
      expect(visible(), ['B75806'], reason: 'vaciar es inmediato');

      expect(products.calls, 1);
    });
  });

  testWidgets('UI: búsqueda, orden y favoritos en el feed', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final favorites = InMemoryFavoritesRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(MockProductRepository(catalog: _catalog, latency: Duration.zero)),
        alertRepositoryProvider.overrideWithValue(MockAlertRepository(latency: Duration.zero)),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
      child: MaterialApp(home: const Scaffold(body: HomeScreen()), onGenerateRoute: AppRouter.onGenerateRoute),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(DealComparisonCard), findsNWidgets(3));

    await tester.enterText(find.byType(SearchBar), 'samba');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DealComparisonCard), findsNWidgets(3));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.byType(DealComparisonCard), findsOneWidget);

    await tester.tap(find.byTooltip('Añadir a favoritos'));
    await tester.pumpAndSettle();
    expect(favorites.stored, {'B75806'});

    await tester.tap(find.byTooltip('Borrar búsqueda'));
    await tester.pumpAndSettle();
    expect(find.byType(DealComparisonCard), findsNWidgets(3));

    await tester.tap(find.text('Mis favoritos (1)'));
    await tester.pumpAndSettle();
    expect(find.byType(DealComparisonCard), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar de favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Sin favoritos que mostrar'), findsOneWidget);

    await tester.tap(find.text('Ver todos los chollos'));
    await tester.tap(find.text(DealSort.discount.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DealSort.name.label).last);
    await tester.pumpAndSettle();
    final cards = tester.widgetList<DealComparisonCard>(find.byType(DealComparisonCard));
    expect(_skus(cards.map((c) => c.deal)), ['HQ8708', 'B75806', 'HF5441-100']);
  });
}
