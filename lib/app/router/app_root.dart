import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/active_trip_provider.dart';
import '../sync/personal_sync.dart';
import '../sync/personal_data.dart';

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(personalDataProvider);
    ref.watch(personalSyncProvider);
    return Scaffold(
      body: Column(
        children: [
          if (ref.watch(activeTripProvider)?.running ?? false)
            SafeArea(
              bottom: false,
              child: ListTile(
                key: const ValueKey('active.resume'),
                leading: const Icon(Icons.navigation),
                title: Text(context.l10n.activeTrip),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/viaje'),
              ),
            ),
          Expanded(child: navigationShell),
        ],
      ),
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
}
