import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:radarprice/domain/models/models.dart';
import 'package:radarprice/domain/services/deal_comparison.dart';
import 'package:radarprice/presentation/widgets/deal_comparison_card.dart';

StoreOffer _offer(String store, double price, {bool simulated = false}) => StoreOffer(
      storeName: store,
      storeLogoUrl: 'https://cdn.test/$store.png',
      price: price,
      inStock: true,
      affiliateUrl: 'https://$store.test/p',
      isSimulated: simulated,
    );

void main() {
  group('StoreOffer.source', () {
    Map<String, dynamic> json(Object? source) => {
          'storeName': 'Zalando',
          'storeLogoUrl': 'https://cdn.test/z.png',
          'price': 89.95,
          'inStock': true,
          'affiliateUrl': 'https://z.test',
          'source': ?source,
        };

    test('simulated / live / ausente (API antigua → real)', () {
      expect(StoreOffer.fromJson(json('simulated')).isSimulated, isTrue);
      expect(StoreOffer.fromJson(json('live')).isSimulated, isFalse);
      expect(StoreOffer.fromJson(json(null)).isSimulated, isFalse);
    });

    test('ida y vuelta JSON conserva la procedencia', () {
      final offer = _offer('StockX', 99, simulated: true);
      expect(StoreOffer.fromJson(offer.toJson()), offer);
      expect(offer, isNot(offer.copyWith(isSimulated: false)));
    });
  });

  testWidgets('la tarjeta marca como "Est." solo las ofertas simuladas', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final product = Product.fromOffers(
      id: 'prd_1',
      sku: 'SKU-1',
      brand: 'Nike',
      model: 'Dunk',
      imageUrl: 'https://cdn.test/1.webp',
      retailPrice: 120,
      sizeOffers: {
        '42': [_offer('Nike', 119.99), _offer('StockX', 95, simulated: true)],
      },
    );
    final deal = buildDealComparison(product, size: '42')!;

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DealComparisonCard(deal: deal))));

    expect(find.byType(EstimatedTag), findsOneWidget);
    final labels = [
      for (final w in tester.widgetList<Semantics>(find.byType(Semantics))) ?w.properties.label,
    ];
    expect(labels.where((l) => l.startsWith('StockX:') && l.contains('estimado')), hasLength(1));
    expect(labels.where((l) => l.startsWith('Nike:') && l.contains('estimado')), isEmpty);
  });
}
