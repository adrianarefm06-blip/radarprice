import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/models/models.dart';
import '../theme/app_colors.dart';
import '../utils/store_launcher.dart';
import '../widgets/estimated_tag.dart';

/// Página pública de privacidad servida por la API (misma URL para Google Play / App Store).
final privacyPolicyUrl = '${kApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/privacidad';

/// Tiendas con precios reales en el catálogo cargado, en orden alfabético.
List<String> liveStoreNames(List<Product> catalog) => ({
  for (final product in catalog)
    for (final offers in product.sizeOffers.values)
      for (final offer in offers)
        if (!offer.isSimulated) offer.storeName,
}.toList()..sort());

/// Cómo funciona RadarPrice, procedencia de los datos y privacidad.
/// El texto de privacidad coincide con el publicado en [privacyPolicyUrl].
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = liveStoreNames(ref.watch(allDealsProvider).value ?? const []);
    final storesText = switch (stores) {
      [] => 'Los precios reales',
      [final only] => 'Los precios de $only',
      _ => 'Los precios de ${stores.sublist(0, stores.length - 1).join(', ')} y ${stores.last}',
    };
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.4);

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
    Widget paragraph(String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(value, style: muted),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de RadarPrice')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          section('Cómo funciona', [
            paragraph(
              'RadarPrice compara el precio de cada zapatilla por talla entre tiendas online '
              'y te avisa cuando baja del precio que elijas.',
            ),
            paragraph('Los precios se actualizan automáticamente cada 6 horas.'),
          ]),
          section('Precios reales y estimados', [
            paragraph('$storesText se leen directamente de las webs de las tiendas.'),
            Row(
              children: [
                const EstimatedTag(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('marca los precios de demostración (estimados), aún sin tienda real.', style: muted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            paragraph(
              'Los precios son orientativos: confírmalos siempre en la tienda antes de comprar. '
              'RadarPrice no vende productos ni gestiona pedidos.',
            ),
          ]),
          section('Imágenes y marcas', [
            paragraph(
              'Las fotos de producto proceden de las webs de las tiendas y las marcas, '
              'que conservan todos sus derechos. Los nombres de marcas y tiendas se usan solo para '
              'identificar los productos.',
            ),
          ]),
          section('Privacidad', [
            paragraph('No hay cuentas ni pedimos datos personales. No usamos analítica ni publicidad.'),
            paragraph('Favoritos: se guardan solo en este dispositivo.'),
            paragraph(
              'Alertas: se guardan en nuestro servidor asociadas a un identificador aleatorio '
              'generado en este dispositivo, sin relación con tu identidad. Al borrar una alerta se '
              'elimina del servidor; al desinstalar la app el identificador se pierde.',
            ),
            paragraph('Al abrir una tienda sales de RadarPrice: se aplica la política de privacidad de esa tienda.'),
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => openExternalUrl(context, privacyPolicyUrl, label: 'la política de privacidad'),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Política de privacidad completa'),
            ),
          ]),
        ],
      ),
    );
  }
}
