import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowayki_lab/app/features/search/presentation/search_screen.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/providers/map_providers.dart';
import 'package:gowayki_lab/app/providers/search_providers.dart';
import 'package:gowayki_lab/core/models/place_result.dart';
import 'package:gowayki_lab/data/app_services.dart';
import 'package:gowayki_lab/domain/models/navigation_search.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_installer.dart';
import 'package:gowayki_lab/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late ProviderContainer container;
  late AppServices services;
  late PlaceResult tecsup;
  late Completer<List<NavigationSearchResult>> slowSearch;
  const origin = PlaceResult(
    id: 'current-location',
    name: 'Mi ubicación',
    address: '',
    latitude: -16.4,
    longitude: -71.54,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    support = await Directory.systemTemp.createTemp('gowayki-search-test-');
    slowSearch = Completer<List<NavigationSearchResult>>();
    container = ProviderContainer(
      overrides: [
        navigationSearchProvider.overrideWith(
          (ref, query) async => query == 'delayed'
              ? await slowSearch.future
              : await ref
                    .watch(cityPackRepositoryProvider)
                    .searchNavigation(query),
        ),
        cityPackInstallerProvider.overrideWithValue(
          CityPackInstaller(supportDirectory: () async => support),
        ),
      ],
    );
    services = await container.read(appServicesProvider.future);
    await container.read(transitMapDataProvider.future);
    tecsup = (await services.cityPack.searchNavigation(
      'tecsup',
    )).firstWhere((r) => r.group == NavigationSearchGroup.place).point!;
    container.read(recentPlacesProvider);
  });
  tearDown(() async {
    container.dispose();
    await services.close();
    if (p.dirname(p.normalize(support.absolute.path)) !=
            p.normalize(Directory.systemTemp.absolute.path) ||
        !p.basename(support.path).startsWith('gowayki-search-test-')) {
      throw StateError('Unsafe cleanup');
    }
    await support.delete(recursive: true);
  });
  Future<void> mount(WidgetTester tester, SearchArguments arguments) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: SearchScreen(arguments: arguments),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'TECSUP se elige con ubicación real como origen y se guarda en recientes',
    (tester) async {
      await mount(tester, const SearchArguments(currentLocation: origin));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('search.usePoints')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('search.destination')),
        'tecsup',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Lugares'), findsOneWidget);
      await tester.tap(find.text(tecsup.name).first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('search.usePoints')),
            )
            .onPressed,
        isNotNull,
      );
      expect(container.read(recentPlacesProvider).first.id, tecsup.id);
      await tester.tap(find.byKey(const ValueKey('search.swap')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('search.origin')))
            .controller!
            .text,
        tecsup.name,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('search.destination')))
            .controller!
            .text,
        'Mi ubicación',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'sin ubicación no inventa origen y un punto borrado impide continuar',
    (tester) async {
      await mount(tester, SearchArguments(destination: tecsup));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('search.origin')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('search.usePoints')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('search.origin')),
        'zzzz_no_result',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('respuesta antigua no reemplaza una búsqueda posterior', (
    tester,
  ) async {
    await mount(tester, const SearchArguments(currentLocation: origin));
    await tester.enterText(
      find.byKey(const ValueKey('search.destination')),
      'delayed',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('search.destination')),
      'zzzz_no_result',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    slowSearch.complete([
      NavigationSearchResult(
        id: tecsup.id,
        name: tecsup.name,
        detail: '',
        group: NavigationSearchGroup.place,
        point: tecsup,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Sin resultados'), findsOneWidget);
    expect(find.text(tecsup.name), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('pantalla pequeña con teclado y texto grande no desborda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.8),
              viewInsets: const EdgeInsets.only(bottom: 260),
            ),
            child: child!,
          ),
          home: SearchScreen(arguments: SearchArguments(destination: tecsup)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'recientes deduplicados, máximo 30 y persistencia al recrear ámbito',
    () async {
      final recent = container.read(recentPlacesProvider.notifier);
      for (var i = 0; i < 35; i++) {
        await recent.remember(
          PlaceResult(
            id: 'point:$i',
            name: 'Point $i',
            address: '',
            latitude: -16.4,
            longitude: -71.5,
          ),
        );
      }
      await recent.remember(tecsup);
      await recent.remember(tecsup);
      await recent.remember(origin);
      expect(container.read(recentPlacesProvider), hasLength(30));
      expect(container.read(recentPlacesProvider).first.id, tecsup.id);
      final fresh = ProviderContainer(
        overrides: [appServicesProvider.overrideWith((ref) async => services)],
      );
      try {
        await fresh.read(appServicesProvider.future);
        expect(
          fresh.read(recentPlacesProvider).map((p) => p.id),
          container.read(recentPlacesProvider).map((p) => p.id),
        );
      } finally {
        fresh.dispose();
      }
    },
  );
}
