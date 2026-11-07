import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowayki_lab/app.dart';
import 'package:gowayki_lab/app/library/local_library.dart';
import 'package:gowayki_lab/app/features/lines/presentation/screens/line_detail_screen.dart';
import 'package:gowayki_lab/app/features/stops/presentation/stop_detail_screen.dart';
import 'package:gowayki_lab/app/features/search/presentation/search_screen.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/providers/location_providers.dart';
import 'package:gowayki_lab/app/providers/map_providers.dart';
import 'package:gowayki_lab/app/providers/map_renderer_provider.dart';
import 'package:gowayki_lab/app/providers/planner_providers.dart';
import 'package:gowayki_lab/app/providers/search_providers.dart';
import 'package:gowayki_lab/app/providers/transit_details_providers.dart';
import 'package:gowayki_lab/app/router/app_router.dart';
import 'package:gowayki_lab/app/settings/app_settings.dart';
import 'package:gowayki_lab/app/features/explorer/presentation/widgets/explorer_map.dart';
import 'package:gowayki_lab/core/models/place_result.dart';
import 'package:gowayki_lab/data/app_services.dart';
import 'package:gowayki_lab/domain/repositories/location_permission_repository.dart';
import 'package:gowayki_lab/domain/repositories/position_repository.dart';
import 'package:gowayki_lab/domain/models/navigation_search.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_installer.dart';

class AllowedPermission implements LocationPermissionRepository {
  @override
  Future<LocationAccess> check() async => LocationAccess.allowed;
  @override
  Future<LocationAccess> request() =>
      throw StateError('Unexpected permission request');
  @override
  Future<bool> openSettings() async => true;
}

class SamplePosition implements PositionRepository {
  SamplePosition(this.getFix);
  final PositionFix Function() getFix;
  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<PositionFix> current() async => getFix();
  @override
  Stream<PositionFix> watch() => const Stream.empty();
  @override
  Future<bool> openServiceSettings() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late ProviderContainer container;
  late AppServices services;
  late LineDetailsData line;
  late StopDetailsData stop;
  late PlaceResult place;
  late ExplorerMap map;
  late PositionFix sampleFix;
  final subscriptions = <ProviderSubscription>[];
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding.done': true});
    support = await Directory.systemTemp.createTemp('gowayki-details-test-');
    container = ProviderContainer(
      overrides: [
        cityPackInstallerProvider.overrideWithValue(
          CityPackInstaller(supportDirectory: () async => support),
        ),
        initialLocationProvider.overrideWithValue('/rutas'),
        explorePageBuilderProvider.overrideWithValue(
          (context) => const Scaffold(body: Text('Explorar de prueba')),
        ),
        appClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 6, 15)),
        currentPositionProvider.overrideWith((ref) async => null),
        locationPermissionRepositoryProvider.overrideWithValue(
          AllowedPermission(),
        ),
        positionRepositoryProvider.overrideWithValue(
          SamplePosition(() => sampleFix),
        ),
        explorerMapRendererProvider.overrideWithValue((value) {
          map = value;
          return const ColoredBox(color: Colors.grey);
        }),
      ],
    );
    services = await container.read(appServicesProvider.future);
    await container.read(appSettingsProvider.future);
    await container.read(localLibraryProvider.future);
    await container.read(transitMapDataProvider.future);
    final first = (await container.read(cityLinesProvider.future)).first;
    subscriptions.add(
      container.listen(lineDetailsProvider(first.id), (previous, next) {}),
    );
    line = await container.read(lineDetailsProvider(first.id).future);
    final id = line.visits[line.patterns.first.id]!.first.stop.id;
    subscriptions.add(
      container.listen(stopDetailsProvider(id), (previous, next) {}),
    );
    stop = await container.read(stopDetailsProvider(id).future);
    sampleFix = PositionFix(
      point: GeoPoint.stop(stop.entry.stop),
      accuracyMeters: 5,
      at: DateTime.utc(2026, 11, 6, 15),
    );
    place = (await services.cityPack.searchNavigation(
      'tecsup',
    )).firstWhere((r) => r.group == NavigationSearchGroup.place).point!;
  });
  tearDown(() async {
    for (final sub in subscriptions) {
      sub.close();
    }
    subscriptions.clear();
    container.dispose();
    await services.close();
    if (p.dirname(p.normalize(support.absolute.path)) !=
            p.normalize(Directory.systemTemp.absolute.path) ||
        !p.basename(support.path).startsWith('gowayki-details-test-')) {
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

  testWidgets('ficha de línea abre paradero real y guarda su favorito', (
    tester,
  ) async {
    await mount(tester);
    container.read(appRouterProvider).push<void>('/linea/${line.line.id}');
    await tester.pumpAndSettle();
    expect(find.byType(LineDetailScreen), findsOneWidget);
    expect(map.focusedLineId, line.line.id);
    expect(line.visits[line.patterns.first.id]!.first.sequence, 1);
    map.onStopTap!(stop.entry);
    await tester.pumpAndSettle();
    expect(find.byType(StopDetailScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stopDetail.favorite')));
    await tester.pumpAndSettle();
    expect(
      container
          .read(localLibraryProvider)
          .requireValue
          .contains('stop:${stop.entry.stop.id}'),
      isTrue,
    );
    await tester.scrollUntilVisible(find.text('Ir aquí'), 180);
    await tester.tap(find.text('Ir aquí'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('search.destination')))
          .controller!
          .text,
      stop.entry.stop.name,
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'filtro cercano usa una posición real del proveedor sin pedir permiso',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Pasan cerca de mí'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('line-${line.line.id}')), findsOneWidget);
      expect(find.text('Un momento…'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Casa se configura, favoritos se reordenan y un deslizamiento borra',
    (tester) async {
      final controller = container.read(localLibraryProvider.notifier);
      await controller.setSpecial(LibraryKind.home, place);
      await controller.toggle(
        LibraryItem(
          id: 'place:${place.id}',
          kind: LibraryKind.place,
          label: place.name,
          point: place,
        ),
      );
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('nav.favorites')));
      await tester.pumpAndSettle();
      final reorder = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView).first,
      );
      reorder.onReorderItem!(0, 1);
      await tester.pumpAndSettle();
      expect(
        container.read(localLibraryProvider).requireValue.order.first,
        'place:${place.id}',
      );
      final row = find.byKey(ValueKey('library.place:${place.id}'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.drag(row, const Offset(-750, 0));
      await tester.pumpAndSettle();
      expect(
        container
            .read(localLibraryProvider)
            .requireValue
            .contains('place:${place.id}'),
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('library.configure.home')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('search.origin')), findsNothing);
      container.read(appRouterProvider).pop(place);
      await tester.pumpAndSettle();
      expect(
        container
            .read(localLibraryProvider)
            .requireValue
            .special(LibraryKind.home)!
            .point!
            .id,
        place.id,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('recientes se borran por deslizamiento y el orden persiste', (
    tester,
  ) async {
    final recent = container.read(recentPlacesProvider.notifier);
    await recent.remember(place);
    final other = PlaceResult(
      id: stop.entry.stop.id,
      name: stop.entry.stop.name,
      address: '',
      latitude: stop.entry.stop.latitude,
      longitude: stop.entry.stop.longitude,
    );
    await recent.remember(other);
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('nav.favorites')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recientes'));
    await tester.pumpAndSettle();
    final reorder = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView).last,
    );
    reorder.onReorderItem!(0, 1);
    await tester.pumpAndSettle();
    expect(container.read(recentPlacesProvider).first.id, place.id);
    final row = find.byKey(ValueKey('recent.${other.id}'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.drag(row, const Offset(-750, 0));
    await tester.pumpAndSettle();
    expect(container.read(recentPlacesProvider).map((p) => p.id), [place.id]);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
