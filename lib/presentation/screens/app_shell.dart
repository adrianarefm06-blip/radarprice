import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _tabs = <Widget>[HomeScreen(), SearchScreen(), AlertsScreen()];
  int _index = 0;

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
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
              icon: Icon(Icons.notifications_none_rounded),
              activeIcon: Icon(Icons.notifications_rounded),
              label: 'Alertas',
            ),
          ],
        ),
      ),
    );
  }
}
