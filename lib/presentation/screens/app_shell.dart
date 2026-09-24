import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../theme/app_colors.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  static const alertsTab = 2;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _tabs = <Widget>[HomeScreen(), SearchScreen(), AlertsScreen()];
  int _index = 0;

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    // El servidor evalúa las alertas en cada sync: refrescar al entrar en la pestaña.
    if (index == AppShell.alertsTab) ref.invalidate(alertsProvider);
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack conserva scroll y estado de cada pestaña.
      // HeroMode evita tags duplicados entre pestañas ocultas (Chollos/Búsqueda).
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++) HeroMode(enabled: i == _index, child: _tabs[i]),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.outline, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: _select,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.local_fire_department_outlined),
              activeIcon: Icon(Icons.local_fire_department_rounded),
              label: 'Chollos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'Buscar',
            ),
            BottomNavigationBarItem(
              icon: _AlertsIcon(icon: Icons.notifications_none_rounded),
              activeIcon: _AlertsIcon(icon: Icons.notifications_rounded),
              label: 'Alertas',
            ),
          ],
        ),
      ),
    );
  }
}

/// Icono de Alertas con el número de alertas cuyo precio se ha alcanzado.
class _AlertsIcon extends ConsumerWidget {
  const _AlertsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(triggeredAlertCountProvider);
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppColors.deal,
      textColor: AppColors.onDeal,
      child: Icon(icon),
    );
  }
}
