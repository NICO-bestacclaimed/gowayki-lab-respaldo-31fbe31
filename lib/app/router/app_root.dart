import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/place_result.dart';
import '../../data/service_locator.dart';
import '../features/explorer/presentation/screens/explorer_screen.dart';
import '../features/feedback/presentation/screens/feedback_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/planner/presentation/screens/planner_screen.dart';
import '../features/profile/presentation/screens/menu_sheet_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/sign_in/presentation/screens/sign_in_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';

enum _Phase { splash, onboarding, signIn, home }

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  _Phase _phase = _Phase.splash;
  final _nav = GlobalKey<NavigatorState>();

  Future<void> _leaveSplash() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding.done') ?? false;
    final loggedIn = ServiceLocator.auth.currentUser != null;
    setState(() {
      if (!seen) {
        _phase = _Phase.onboarding;
      } else if (!loggedIn) {
        _phase = _Phase.signIn;
      } else {
        _phase = _Phase.home;
      }
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding.done', true);
    setState(() => _phase = _Phase.signIn);
  }

  void _openPlanner(PlaceResult destination) {
    _nav.currentState?.push(
      MaterialPageRoute(builder: (_) => PlannerScreen(destination: destination)),
    );
  }

  void _openMenu() {
    _nav.currentState?.push(
      MaterialPageRoute(
        builder: (_) => MenuSheetScreen(
          onOpenProfile: () {
            _nav.currentState?.push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
          onOpenSettings: () {
            _nav.currentState?.push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          onOpenFeedback: () {
            _nav.currentState?.push(
              MaterialPageRoute(builder: (_) => const FeedbackScreen()),
            );
          },
          onSignOut: () {
            _nav.currentState?.popUntil((r) => r.isFirst);
            setState(() => _phase = _Phase.signIn);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.splash => SplashScreen(onReady: _leaveSplash),
      _Phase.onboarding => OnboardingScreen(onFinish: _finishOnboarding),
      _Phase.signIn => SignInScreen(
          onSignedIn: () => setState(() => _phase = _Phase.home),
          onBackToOnboarding: () => setState(() => _phase = _Phase.onboarding),
        ),
      _Phase.home => Navigator(
          key: _nav,
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => ExplorerScreen(
              onPlanTrip: _openPlanner,
              onOpenMenu: _openMenu,
            ),
          ),
        ),
    };
  }
}
