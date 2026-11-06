import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/providers/app_providers.dart';
import 'app/router/app_router.dart';
import 'app/settings/app_settings.dart';
import 'app/features/splash/presentation/screens/splash_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/theme/theme.dart';
import 'shared/widgets/content_state.dart';
import 'shared/l10n/l10n.dart';

class GowaykiLabApp extends ConsumerWidget {
  const GowaykiLabApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(appServicesProvider);
    final settings =
        ref.watch(appSettingsProvider).asData?.value ?? const AppSettings();
    if (services.hasValue) {
      return MaterialApp.router(
        title: 'GoWayki',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: settings.theme,
        locale: settings.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback: _locale,
        routerConfig: ref.watch(appRouterProvider),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.theme,
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: _locale,
      home: services.hasError
          ? Builder(
              builder: (context) => Scaffold(
                body: ContentState(
                  kind: ContentStateKind.error,
                  message: context.l10n.bootstrapError,
                  onAction: () => ref.invalidate(appServicesProvider),
                ),
              ),
            )
          : const SplashScreen(),
    );
  }

  static Locale _locale(Locale? requested, Iterable<Locale> supported) =>
      requested?.languageCode == 'en'
      ? const Locale('en')
      : const Locale('es', 'PE');
}
