import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/services/store_catalog.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/segment_toggle.dart';
import '../widgets/state_views.dart';
import '../widgets/store_card.dart';
import 'best_deals_view.dart';

enum _HomeMode {
  deals('Mejores chollos'),
  stores('Por tienda');

  const _HomeMode(this.label);

  final String label;
}

/// Chollos: feed global comparado por talla ([BestDealsView]) o catálogo de tiendas
/// → [StoreDealsScreen]. Ambas vistas comparten [allDealsProvider] (una sola petición).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 240,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 0.9,
  );
  static const _gridPadding = EdgeInsets.fromLTRB(16, 10, 16, 24);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeMode _mode = _HomeMode.deals;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('RadarPrice', style: text.headlineMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              _mode == _HomeMode.deals
                  ? 'Los mayores descuentos de todas las tiendas'
                  : 'Elige una tienda y descubre sus chollos',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SegmentToggle<_HomeMode>(
              segments: _HomeMode.values,
              selected: _mode,
              labelOf: (mode) => mode.label,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
          ),
          Expanded(
            // IndexedStack conserva el scroll de cada vista. HeroMode evita tags duplicados.
            child: IndexedStack(
              index: _mode.index,
              children: [
                HeroMode(enabled: _mode == _HomeMode.deals, child: const BestDealsView()),
                HeroMode(enabled: _mode == _HomeMode.stores, child: const _StoresView()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoresView extends ConsumerWidget {
  const _StoresView();

  Future<void> _refresh(WidgetRef ref) async {
    try {
      ref.invalidate(allDealsProvider);
      await ref.read(allDealsProvider.future);
    } catch (_) {
      // El error queda reflejado en el estado; no romper el indicador.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(storeSummariesProvider);

    return Column(
      children: [
        SizedBox(
          height: 2,
          child: stores.isLoading && stores.hasValue ? const LinearProgressIndicator(minHeight: 2) : null,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: stores.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: HomeScreen._gridPadding,
                gridDelegate: HomeScreen._gridDelegate,
                itemCount: 4,
                itemBuilder: (_, __) => const StoreCardSkeleton(),
              ),
              error: (error, _) => PullToRefreshFill(
                child: ErrorStateView(error: error, onRetry: () => ref.invalidate(allDealsProvider)),
              ),
              data: (summaries) => summaries.isEmpty
                  ? const PullToRefreshFill(
                      child: StateMessageView(
                        icon: Icons.storefront_outlined,
                        title: 'Aún no hay tiendas',
                        message: 'Desliza hacia abajo para buscar ofertas de nuevo.',
                      ),
                    )
                  : _StoreGrid(summaries: summaries),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoreGrid extends StatelessWidget {
  const _StoreGrid({required this.summaries});

  final List<StoreSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: HomeScreen._gridPadding,
      gridDelegate: HomeScreen._gridDelegate,
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return StoreCard(
          key: ValueKey(summary.storeName),
          summary: summary,
          onTap: () => AppRouter.openStore(context, summary.storeName),
        );
      },
    );
  }
}
