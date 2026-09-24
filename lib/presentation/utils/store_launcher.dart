import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/models.dart';

/// Abre la tienda fuera de la app (navegador o app nativa de la tienda).
/// Solo http/https: nunca se lanzan esquemas arbitrarios desde datos remotos.
Future<void> openStoreOffer(BuildContext context, StoreOffer offer) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(offer.affiliateUrl);
  var opened = false;

  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      opened = false;
    }
  }

  if (!opened) {
    messenger.showSnackBar(
      SnackBar(content: Text('No se pudo abrir ${offer.storeName}. Comprueba que tienes un navegador instalado.')),
    );
  }
}
