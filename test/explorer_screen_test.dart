import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowayki_lab/app.dart';
import 'package:gowayki_lab/app/features/explorer/presentation/screens/explorer_screen.dart';
import 'package:gowayki_lab/app/features/explorer/presentation/widgets/explorer_map.dart';
import 'package:gowayki_lab/app/features/search/presentation/search_screen.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/providers/location_providers.dart';
import 'package:gowayki_lab/app/providers/map_providers.dart';
import 'package:gowayki_lab/app/router/app_router.dart';
import 'package:gowayki_lab/app/settings/app_settings.dart';
import 'package:gowayki_lab/core/models/place_result.dart';
import 'package:gowayki_lab/data/app_services.dart';
import 'package:gowayki_lab/domain/models/navigation_search.dart';
import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_installer.dart';

class NoLocation extends ExplorerLocationController {
  @override
  ExplorerLocation build() => const ExplorerLocation(LocationStatus.permission);
  @override
  Future<void> start({bool refresh = false}) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late ProviderContainer container;
  late AppServices services;
  late ExplorerMap captured;
  late PlaceResult tecsup, mall;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding.done': true});
    support = await Directory.systemTemp.createTemp('gowayki-explorer-test-');
    container = ProviderContainer(
      overrides: [
        cityPackInstallerProvider.overrideWithValue(
          CityPackInstaller(supportDirectory: () async => support),
        ),
        explorerLocationProvider.overrideWith(NoLocation.new),
        explorerMapRendererProvider.overrideWithValue((map) {
          captured = map;
          return const ColoredBox(color: Colors.grey);
        }),
      ],
    );
    services = await container.read(appServicesProvider.future);
    await container.read(appSettingsProvider.future);
    await container.read(transitMapDataProvider.future);
    tecsup = (await services.cityPack.searchNavigation(
      'tecsup',
    )).firstWhere((r) => r.group == NavigationSearchGroup.place).point!;
    mall = (await services.cityPack.searchNavigation(
      'mall aventura',
    )).firstWhere((r) => r.group == NavigationSearchGroup.place).point!;
  });
  tearDown(() async {
    container.dispose();
    await services.close();
    if (p.dirname(p.normalize(support.absolute.path)) !=
            p.normalize(Directory.systemTemp.absolute.path) ||
        !p.basename(support.path).startsWith('gowayki-explorer-test-')) {
      throw StateError('Unsafe cleanup');
    }
    await support.delete(recursive: true);
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const GowaykiLabApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sin permiso no muestra posición ficticia; buscar devuelve ambos marcadores',
    (tester) async {
      await mount(tester);
      expect(captured.position, isNull);
      expect(find.text('Paraderos cerca de ti'), findsOneWidget);
      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      expect(sheet.snapSizes, [.16, .26, .70]);
      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      container
          .read(appRouterProvider)
          .pop(JourneyEndpoints(origin: tecsup, destination: mall));
      await tester.pumpAndSettle();
      expect(captured.origin!.latitude, tecsup.latitude);
      expect(captured.destination!.longitude, mall.longitude);
      expect(captured.position, isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('pulsación larga ofrece acciones con coordenadas elegidas', (
    tester,
  ) async {
    await mount(tester);
    captured.onLongPress!(GeoPoint(tecsup.latitude, tecsup.longitude));
    await tester.pumpAndSettle();
    expect(find.text('Ir aquí'), findsOneWidget);
    expect(find.text('Salir desde aquí'), findsOneWidget);
    await tester.tap(find.text('Salir desde aquí'));
    await tester.pumpAndSettle();
    final origin = tester.widget<TextField>(
      find.byKey(const ValueKey('search.origin')),
    );
    expect(origin.controller!.text, 'Punto elegido en el mapa');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('search.usePoints')))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
