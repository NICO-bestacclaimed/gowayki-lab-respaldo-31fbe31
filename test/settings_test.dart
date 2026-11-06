import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowayki_lab/app/settings/app_settings.dart';
import 'package:gowayki_lab/app/settings/legal_links.dart';
import 'package:gowayki_lab/app/features/settings/presentation/screens/settings_screen.dart';
import 'package:gowayki_lab/domain/models/city_pack_models.dart';
import 'package:gowayki_lab/l10n/generated/app_localizations.dart';
import 'package:gowayki_lab/shared/theme/app_theme.dart';
import 'package:gowayki_lab/shared/widgets/content_state.dart';
import 'planner/toy_network.dart';

class SettingsHarness extends ConsumerWidget {
  const SettingsHarness({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).requireValue;
    return MaterialApp(
      locale: settings.locale,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    );
  }
}

class FakeOpener implements ExternalLinkOpener {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late FakeOpener opener;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    opener = FakeOpener();
    container = ProviderContainer(
      overrides: [
        packageInfoProvider.overrideWith(
          (ref) async => CityPackInfo(
            cityCode: 'arequipa',
            version: 2,
            generatedAt: DateTime.utc(2026, 11, 6),
            sha256: 'verified',
          ),
        ),
        externalLinkOpenerProvider.overrideWithValue(opener),
      ],
    );
    await container.read(appSettingsProvider.future);
    await container.read(packageInfoProvider.future);
  });
  tearDown(() => container.dispose());
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SettingsHarness(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('idioma y tema se aplican, caminata y alarma se guardan', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('settings.language.es')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(
      container.read(appSettingsProvider).requireValue.languageCode,
      'en',
      reason: 'stored selection',
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale?.languageCode,
      'en',
      reason: 'root locale',
    );
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings.theme.system')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.byKey(const ValueKey('settings.walking.null')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Up to 400 m').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings.avoidTransfers')),
    );
    await tester.tap(find.byKey(const ValueKey('settings.avoidTransfers')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings.alarm.sound')),
    );
    await tester.tap(find.byKey(const ValueKey('settings.alarm.sound')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vibration').last);
    await tester.pumpAndSettle();
    final value = container.read(appSettingsProvider).requireValue;
    expect(value.languageCode, 'en');
    expect(value.theme, ThemeMode.dark);
    expect(value.maxAccessMeters, 400);
    expect(value.maxBoardings, 1);
    expect(value.alarm, AlarmMode.vibration);
    final stored = container
        .read(localSettingsStorageProvider)
        .requireValue
        .getString(SettingsController.storageKey);
    expect(AppSettings.decode(stored).encode(), value.encode());
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('metadatos reales y enlaces no publicados desactivados', (
    tester,
  ) async {
    await mount(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings.update')),
      300,
    );
    expect(find.text('Versión de datos: 2'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('settings.update')))
          .onPressed,
      isNull,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings.privacy')),
      300,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('settings.privacy')))
          .enabled,
      isFalse,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings.terms')),
      100,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('settings.terms')))
          .enabled,
      isFalse,
    );
    await tester.scrollUntilVisible(
      find.text('© Colaboradores de OpenStreetMap · ODbL'),
      -150,
    );
    await tester.tap(find.text('© Colaboradores de OpenStreetMap · ODbL'));
    await tester.pumpAndSettle();
    expect(opener.opened.single.host, 'www.openstreetmap.org');
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'escrituras simultáneas y reinicio conservan todos los ajustes',
    () async {
      final controller = container.read(appSettingsProvider.notifier);
      await Future.wait([
        controller.save((s) => s.copyWith(languageCode: 'en')),
        controller.save((s) => s.copyWith(avoidTransfers: true)),
        controller.save((s) => s.copyWith(theme: ThemeMode.dark)),
      ]);
      final fresh = ProviderContainer();
      try {
        final loaded = await fresh.read(appSettingsProvider.future);
        expect(loaded.languageCode, 'en');
        expect(loaded.avoidTransfers, isTrue);
        expect(loaded.theme, ThemeMode.dark);
      } finally {
        fresh.dispose();
      }
    },
  );
  test('las preferencias aplican límite estricto al planificador', () {
    final base = configured();
    final fixed = const AppSettings(maxAccessMeters: 400, avoidTransfers: true);
    expect(fixed.plannerSettings(base).accessMeters, 400);
    expect(fixed.plannerSettings(base).fallbackMeters, 400);
    expect(fixed.maxBoardings, 1);
    expect(
      const AppSettings().plannerSettings(base).fallbackMeters,
      base.fallbackMeters,
    );
  });
  test('datos dañados y valores inválidos usan valores válidos', () {
    expect(AppSettings.decode('broken').languageCode, 'es');
    final settings = AppSettings.decode(
      '{"language":"xx","theme":"fake","maxAccessMeters":-1,"alarm":"fake"}',
    );
    expect(settings.theme, ThemeMode.system);
    expect(settings.maxAccessMeters, isNull);
    expect(settings.alarm, AlarmMode.sound);
    expect(LegalLinks.parse('javascript:alert(1)'), isNull);
    expect(LegalLinks.parse('https://'), isNull);
  });
  testWidgets('estados compartidos y skeleton sin animación interminable', (
    tester,
  ) async {
    for (final kind in ContentStateKind.values) {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentState(kind: kind, onAction: () => calls++),
          ),
        ),
      );
      await tester.tap(find.text('Reintentar'));
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ContentSkeleton(rows: 3))),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
