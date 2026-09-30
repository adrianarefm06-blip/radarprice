import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/models.dart';

/// Abre la tienda fuera de la app (navegador o app nativa de la tienda).
Future<void> openStoreOffer(BuildContext context, StoreOffer offer) =>
    openExternalUrl(context, offer.affiliateUrl, label: offer.storeName);

/// Abre [url] fuera de la app. Solo http/https: nunca se lanzan esquemas arbitrarios
/// desde datos remotos. Si falla, avisa con un SnackBar.
Future<void> openExternalUrl(BuildContext context, String url, {String label = 'el enlace'}) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(url);
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
      SnackBar(content: Text('No se pudo abrir $label. Comprueba que tienes un navegador instalado.')),
    );
  }
}
