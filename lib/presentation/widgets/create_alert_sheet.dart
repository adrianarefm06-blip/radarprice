import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'state_views.dart';

/// Hoja para crear una alerta de precio de [product]. Devuelve la alerta creada.
class CreateAlertSheet extends ConsumerStatefulWidget {
  const CreateAlertSheet({super.key, required this.product, this.initialSize});

  final Product product;
  final String? initialSize;

  static const maxTargetPrice = 10000.0;

  static Future<PriceAlert?> show(BuildContext context, Product product, {String? initialSize}) =>
      showModalBottomSheet<PriceAlert>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        builder: (_) => CreateAlertSheet(product: product, initialSize: initialSize),
      );

  /// Precio sugerido: 10 % por debajo del precio actual (o del retail sin stock), en euros enteros.
  static double suggestedTarget(double? current, double retail) {
    final base = current ?? retail;
    return (base * 0.9).floorToDouble().clamp(1, maxTargetPrice).toDouble();
  }

  /// '89,95' / '89.95' / '90' → número; `null` si no es válido.
  static double? parsePrice(String raw) {
    final value = double.tryParse(raw.trim().replaceAll('€', '').replaceAll(',', '.'));
    return value == null || value.isNaN ? null : value;
  }

  @override
  ConsumerState<CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends ConsumerState<CreateAlertSheet> {
  late final List<String> _sizes = widget.product.sizeOffers.keys.toList()..sort(Product.compareSizes);
  late String? _size = _sizes.contains(widget.initialSize) ? widget.initialSize : null;
  late final _controller = TextEditingController(text: _formatInput(_suggested()));
  bool _busy = false;
  String? _error;

  double? get _currentPrice {
    final size = _size;
    if (size == null) {
      return widget.product.availableSizes.isEmpty ? null : widget.product.lowestPrice;
    }
    return widget.product.lowestPriceForSize(size);
  }

  double _suggested() => CreateAlertSheet.suggestedTarget(_currentPrice, widget.product.retailPrice);

  static String _formatInput(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2).replaceAll('.', ',');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectSize(String? size) => setState(() {
        _size = size;
        _error = null;
        _controller.text = _formatInput(_suggested());
      });

  Future<void> _submit() async {
    final target = CreateAlertSheet.parsePrice(_controller.text);
    if (target == null || target <= 0) {
      setState(() => _error = 'Introduce un precio válido');
      return;
    }
    if (target > CreateAlertSheet.maxTargetPrice) {
      setState(() => _error = 'El máximo es ${formatPrice(CreateAlertSheet.maxTargetPrice)}');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(alertsProvider.notifier)
          .create(sku: widget.product.sku, targetPrice: target, targetSize: _size);
      if (mounted) Navigator.of(context).pop(created);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userMessageFor(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final existing = ref.watch(alertForProvider((sku: widget.product.sku, size: _size)));
    final current = _currentPrice;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Crear alerta de precio', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(widget.product.displayName, style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String?>(
            initialValue: _size,
            decoration: const InputDecoration(labelText: 'Talla'),
            items: [
              const DropdownMenuItem<String?>(child: Text('Cualquier talla')),
              for (final size in _sizes) DropdownMenuItem<String?>(value: size, child: Text('EU $size')),
            ],
            onChanged: _busy ? null : _selectSize,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('alert-target-price'),
            controller: _controller,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              labelText: 'Avísame cuando baje de',
              suffixText: '€',
              helperText: current == null
                  ? 'Sin stock ahora: te avisamos cuando vuelva por debajo de tu precio'
                  : 'Ahora desde ${formatPrice(current)}',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (existing != null) ...[
            const SizedBox(height: 12),
            Text(
              'Ya tienes una alerta para ${_size == null ? 'cualquier talla' : 'la EU $_size'} '
              '(por debajo de ${formatPrice(existing.targetPrice)}).',
              style: text.bodySmall?.copyWith(color: AppColors.premium),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy || existing != null ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            child: _busy
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Crear alerta'),
          ),
        ],
      ),
    );
  }
}

/// Campana del detalle: rellena si ya hay alguna alerta para el producto.
class AlertBellButton extends ConsumerWidget {
  const AlertBellButton({super.key, required this.product});

  final Product product;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final created = await CreateAlertSheet.show(
      context,
      product,
      initialSize: ref.read(selectedSizeFilterProvider),
    );
    if (created == null) return;
    messenger.showSnackBar(SnackBar(
      content: Text(created.isTriggered
          ? '¡Ya está por debajo de ${formatPrice(created.targetPrice)}! Alerta creada.'
          : 'Alerta creada. Te avisaremos cuando baje de ${formatPrice(created.targetPrice)}.'),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAlert = ref.watch(hasAlertForSkuProvider(product.sku));
    return IconButton(
      tooltip: 'Crear alerta de precio',
      isSelected: hasAlert,
      icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textSecondary),
      selectedIcon: const Icon(Icons.notifications_active_rounded, color: AppColors.textPrimary),
      onPressed: () => _open(context, ref),
    );
  }
}
