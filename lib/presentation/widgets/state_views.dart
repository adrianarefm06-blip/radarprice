import 'package:flutter/material.dart';

import '../../core/errors/app_exceptions.dart';
import '../theme/app_colors.dart';

String userMessageFor(Object error) => switch (error) {
      ProductNotFoundException() => 'Esta zapatilla ya no está en el catálogo.',
      AppException(:final message) => message,
      _ => 'No se pudieron cargar los datos. Comprueba tu conexión y vuelve a intentarlo.',
    };

class StateMessageView extends StatelessWidget {
  const StateMessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = actionLabel;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: text.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
            if (label != null && onAction != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.outline),
                ),
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StateMessageView(
        icon: Icons.cloud_off_rounded,
        title: 'No se pudo cargar',
        message: userMessageFor(error),
        actionLabel: 'Reintentar',
        onAction: onRetry,
      );
}

/// Hace scrollable un estado vacío/error para que el pull-to-refresh funcione.
class PullToRefreshFill extends StatelessWidget {
  const PullToRefreshFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
