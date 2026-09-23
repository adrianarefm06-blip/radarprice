import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../screens/app_shell.dart';
import '../screens/product_detail_screen.dart';
import '../screens/store_deals_screen.dart';
import '../widgets/state_views.dart';

abstract final class AppRouter {
  static const shell = '/';
  static const productDetail = '/product';
  static const storeDeals = '/store';

  /// Pasa el [Product] ya cargado para pintar el detalle al instante (y animar el Hero).
  static Future<void> openProduct(BuildContext context, Product product) =>
      Navigator.of(context).pushNamed(productDetail, arguments: product);

  static Future<void> openStore(BuildContext context, String storeName) =>
      Navigator.of(context).pushNamed(storeDeals, arguments: storeName);

  static Route<dynamic> onGenerateRoute(RouteSettings settings) => switch ((settings.name, settings.arguments)) {
        (shell, _) => MaterialPageRoute<void>(settings: settings, builder: (_) => const AppShell()),
        (productDetail, final Product product) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ProductDetailScreen(sku: product.sku, initialProduct: product),
          ),
        (productDetail, final String sku) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ProductDetailScreen(sku: sku),
          ),
        (storeDeals, final String storeName) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => StoreDealsScreen(storeName: storeName),
          ),
        _ => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(
              body: StateMessageView(
                icon: Icons.explore_off_outlined,
                title: 'Pantalla no disponible',
                message: 'Vuelve atrás e inténtalo desde el menú.',
              ),
            ),
          ),
      };
}
