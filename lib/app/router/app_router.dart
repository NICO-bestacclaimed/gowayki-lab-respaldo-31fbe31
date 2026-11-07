import '../features/search/presentation/search_screen.dart';
import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/place_result.dart';
import '../providers/app_providers.dart';
import '../features/explorer/presentation/screens/explorer_screen.dart';
import '../features/feedback/presentation/screens/feedback_screen.dart';
import '../features/lines/presentation/screens/lines_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/planner/presentation/screens/planner_screen.dart';
import '../features/profile/presentation/screens/menu_sheet_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/sign_in/presentation/screens/sign_in_screen.dart';
import 'app_root.dart';
import '../features/location/presentation/screens/location_disclosure_screen.dart';

final explorePageBuilderProvider = Provider<WidgetBuilder>(
  (ref) =>
      (context) => ExplorerScreen(onOpenMenu: () => context.push('/menu')),
);
final initialLocationProvider = Provider<String?>((ref) => null);
final appRouterProvider = Provider<GoRouter>((ref) {
  final services = ref.watch(appServicesProvider).requireValue;
  final exploreBuilder = ref.watch(explorePageBuilderProvider);
  final router = GoRouter(
    initialLocation:
        ref.watch(initialLocationProvider) ??
        ((services.localPreferences.getBool('onboarding.done') ?? false)
            ? '/explorar'
            : '/bienvenida'),
    redirect: (context, state) {
      final seen =
          services.localPreferences.getBool('onboarding.done') ?? false;
      return !seen &&
              !{'/bienvenida', '/ubicacion'}.contains(state.matchedLocation)
          ? '/bienvenida'
          : null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.pageUnavailable),
            FilledButton(
              onPressed: () => context.go('/explorar'),
              child: Text(context.l10n.backExplore),
            ),
          ],
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/bienvenida',
        builder: (context, state) =>
            OnboardingScreen(onFinish: () => context.go('/ubicacion')),
      ),
      GoRoute(
        path: '/ubicacion',
        builder: (context, state) => LocationDisclosureScreen(
          onContinue: () async {
            final saved = await services.localPreferences.setBool(
              'onboarding.done',
              true,
            );
            if (!saved) throw StateError('No se pudo guardar la preferencia.');
            if (context.mounted) context.go('/explorar');
          },
        ),
      ),
      GoRoute(
        path: '/acceso',
        builder: (context, state) => SignInScreen(
          onSignedIn: () => context.go('/perfil'),
          onBackToOnboarding: () => context.go('/bienvenida'),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppRoot(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explorar',
                builder: (context, state) => exploreBuilder(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rutas',
                builder: (context, state) => const LinesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favoritos',
                builder: (context, state) =>
                    const LinesScreen(favoritesOnly: true),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/perfil',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/planificar',
        builder: (context, state) {
          final destination = state.extra;
          if (destination is PlaceResult) {
            return PlannerScreen(destination: destination);
          }
          return Scaffold(
            body: Center(child: Text(context.l10n.chooseDestination)),
          );
        },
      ),
      GoRoute(
        path: '/buscar',
        builder: (context, state) => SearchScreen(
          arguments: state.extra is SearchArguments
              ? state.extra as SearchArguments
              : const SearchArguments(),
        ),
      ),
      GoRoute(
        path: '/menu',
        builder: (context, state) => MenuSheetScreen(
          onOpenProfile: () => context.go('/perfil'),
          onOpenSettings: () => context.push('/ajustes'),
          onOpenFeedback: () => context.push('/ayuda'),
          onSignOut: () => context.go('/perfil'),
        ),
      ),
      GoRoute(
        path: '/ajustes',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/ayuda',
        builder: (context, state) => const FeedbackScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
