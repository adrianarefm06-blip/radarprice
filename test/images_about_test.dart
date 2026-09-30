import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:radarprice/application/providers/providers.dart';
import 'package:radarprice/data/mock/mock_product_repository.dart';
import 'package:radarprice/domain/models/models.dart';
import 'package:radarprice/presentation/screens/about_screen.dart';
import 'package:radarprice/presentation/widgets/sneaker_image.dart';
import 'package:radarprice/presentation/widgets/store_logo.dart';

StoreOffer _offer(String store, {bool simulated = false}) => StoreOffer(
      storeName: store,
      storeLogoUrl: '',
      price: 99,
      inStock: true,
      affiliateUrl: 'https://$store.test/p',
      isSimulated: simulated,
    );

Product _product(String sku, List<StoreOffer> offers) => Product.fromOffers(
      id: 'prd_$sku',
      sku: sku,
      brand: 'Nike',
      model: 'Modelo $sku',
      imageUrl: '',
      retailPrice: 100,
      sizeOffers: {'42': offers},
    );

final _catalog = [
  _product('A', [_offer('Nike'), _offer('StockX', simulated: true)]),
  _product('B', [_offer('Urban Jungle'), _offer('Asphaltgold'), _offer('Nike')]),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('liveStoreNames: solo tiendas reales, sin duplicados y ordenadas', () {
    expect(liveStoreNames(_catalog), ['Asphaltgold', 'Nike', 'Urban Jungle']);
    expect(liveStoreNames(const []), isEmpty);
  });

  testWidgets('sin foto ni logo: monograma e inicial sin peticiones de red', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Row(children: [
        SizedBox.square(dimension: 100, child: SneakerImage(imageUrl: '', brand: 'Jordan')),
        StoreLogo(logoUrl: '', storeName: 'asphaltgold'),
      ]),
    ));
    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('pantalla Acerca de: tiendas reales del catálogo y privacidad', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(MockProductRepository(catalog: _catalog, latency: Duration.zero)),
      ],
      child: const MaterialApp(home: AboutScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Asphaltgold, Nike y Urban Jungle'), findsOneWidget);
    expect(find.textContaining('No hay cuentas'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Política de privacidad completa'), 200);
    expect(find.text('Política de privacidad completa'), findsOneWidget);
    expect(privacyPolicyUrl, endsWith('/privacidad'));
  });
}
