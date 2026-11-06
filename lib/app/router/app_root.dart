import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: [
        NavigationDestination(
          key: const ValueKey('nav.explore'),
          icon: const Icon(Icons.explore_outlined),
          selectedIcon: const Icon(Icons.explore),
          label: context.l10n.explore,
        ),
        NavigationDestination(
          key: const ValueKey('nav.lines'),
          icon: const Icon(Icons.route_outlined),
          selectedIcon: const Icon(Icons.route),
          label: context.l10n.routes,
        ),
        NavigationDestination(
          key: const ValueKey('nav.favorites'),
          icon: const Icon(Icons.star_border),
          selectedIcon: const Icon(Icons.star),
          label: context.l10n.favorites,
        ),
        NavigationDestination(
          key: const ValueKey('nav.profile'),
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: context.l10n.profile,
        ),
      ],
    ),
  );
}
