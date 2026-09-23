import '../../core/constants/sizes.dart';
import '../../domain/models/models.dart';

// Assets servidos por el CDN propio (placeholders hasta tener backend).
// La UI debe usar errorBuilder / placeholder en Image.network.
const _imageCdn = 'https://cdn.radarprice.app/products';
const _logoCdn = 'https://cdn.radarprice.app/stores';

class _Store {
  const _Store(this.name, this.logoFile, this.searchUrlTemplate);

  final String name;
  final String logoFile;

  /// `{sku}` se sustituye por el SKU. El tag de afiliado lo inyectará el backend.
  final String searchUrlTemplate;

  String get logoUrl => '$_logoCdn/$logoFile';

  String affiliateUrlFor(String sku) =>
      searchUrlTemplate.replaceAll('{sku}', Uri.encodeQueryComponent(sku));
}

const _nike = _Store('Nike', 'nike.png', 'https://www.nike.com/es/w?q={sku}');
const _footLocker = _Store('Foot Locker', 'footlocker.png', 'https://www.footlocker.es/es/search?query={sku}');
const _stockX = _Store('StockX', 'stockx.png', 'https://stockx.com/es-es/search?s={sku}');
const _adidas = _Store('adidas', 'adidas.png', 'https://www.adidas.es/search?q={sku}');
const _zalando = _Store('Zalando', 'zalando.png', 'https://www.zalando.es/catalogo/?q={sku}');

typedef _Quote = (double price, bool inStock);
typedef _StoreQuotes = (_Store store, Map<String, _Quote> quotes);

/// Catálogo semilla (precios EUR, mercado ES). Determinista: no usa aleatoriedad.
List<Product> buildMockCatalog() => List.unmodifiable([
      _product(
        sku: 'DH6927-111',
        brand: 'Jordan',
        model: 'Air Jordan 4 Retro "Military Black"',
        retailPrice: 210.0,
        stores: [
          (_nike, {
            '41': (210.0, false),
            '42': (210.0, false),
            '42.5': (210.0, false),
            '43': (210.0, false),
            '44': (210.0, true),
          }),
          (_footLocker, {
            '41': (219.99, true),
            '42': (219.99, false),
            '42.5': (219.99, true),
            '43': (219.99, true),
            '44': (219.99, false),
          }),
          (_stockX, {
            '41': (268.0, true),
            '42': (245.0, true),
            '42.5': (239.0, true),
            '43': (252.0, true),
            '44': (231.0, true),
          }),
        ],
      ),
      _product(
        sku: 'HQ8708',
        brand: 'adidas',
        model: 'Campus 00s "Core Black"',
        retailPrice: 120.0,
        stores: [
          (_adidas, {
            '41': (120.0, true),
            '42': (120.0, false),
            '42.5': (120.0, true),
            '43': (120.0, true),
            '44': (120.0, false),
          }),
          (_footLocker, {
            '41': (99.99, true),
            '42': (99.99, true),
            '42.5': (109.99, true),
            '43': (99.99, false),
            '44': (109.99, true),
          }),
          (_zalando, {
            '41': (89.95, false),
            '42': (94.95, true),
            '42.5': (94.95, true),
            '43': (89.95, true),
            '44': (99.95, true),
          }),
          (_stockX, {
            '41': (104.0, true),
            '42': (98.0, true),
            '42.5': (112.0, true),
            '43': (101.0, true),
            '44': (96.0, true),
          }),
        ],
      ),
      _product(
        sku: 'DD1391-100',
        brand: 'Nike',
        model: 'Dunk Low Retro "White Black" (Panda)',
        retailPrice: 119.99,
        stores: [
          (_nike, {
            '41': (119.99, true),
            '42': (119.99, false),
            '42.5': (119.99, false),
            '43': (119.99, true),
            '44': (119.99, false),
          }),
          (_footLocker, {
            '41': (109.99, true),
            '42': (109.99, true),
            '42.5': (119.99, true),
            '43': (99.99, true),
            '44': (119.99, false),
          }),
          (_stockX, {
            '41': (96.0, true),
            '42': (102.0, true),
            '42.5': (108.0, true),
            '43': (99.0, true),
            '44': (93.0, true),
          }),
        ],
      ),
    ]);

Product _product({
  required String sku,
  required String brand,
  required String model,
  required double retailPrice,
  required List<_StoreQuotes> stores,
}) {
  final slug = sku.toLowerCase();
  return Product.fromOffers(
    id: 'prd_$slug',
    sku: sku,
    brand: brand,
    model: model,
    imageUrl: '$_imageCdn/$slug.webp',
    retailPrice: retailPrice,
    sizeOffers: _groupBySize(sku, stores),
  );
}

Map<String, List<StoreOffer>> _groupBySize(String sku, List<_StoreQuotes> stores) {
  // Pre-sembrado con kSupportedSizes para mantener el orden de tallas estable.
  final bySize = <String, List<StoreOffer>>{
    for (final size in kSupportedSizes) size: <StoreOffer>[],
  };
  for (final (store, quotes) in stores) {
    for (final MapEntry(key: size, value: (price, inStock)) in quotes.entries) {
      (bySize[size] ??= <StoreOffer>[]).add(
        StoreOffer(
          storeName: store.name,
          storeLogoUrl: store.logoUrl,
          price: price,
          inStock: inStock,
          affiliateUrl: store.affiliateUrlFor(sku),
        ),
      );
    }
  }
  return bySize..removeWhere((_, offers) => offers.isEmpty);
}
