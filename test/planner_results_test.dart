import 'dart:async';
import 'package:gowayki_lab/app/library/local_library.dart';
import 'package:gowayki_lab/app/providers/sharing_providers.dart';
import 'package:gowayki_lab/app/features/planner/presentation/screens/itinerary_detail_screen.dart';
import 'package:gowayki_lab/app/features/planner/presentation/widgets/journey_instructions.dart';
import 'package:gowayki_lab/l10n/generated/app_localizations_es.dart';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:gowayki_lab/app/features/explorer/presentation/widgets/explorer_map.dart';
import 'package:gowayki_lab/app/features/planner/presentation/screens/planner_screen.dart';
import 'package:gowayki_lab/app/features/planner/presentation/widgets/itinerary_card.dart';
import 'package:gowayki_lab/app/providers/map_renderer_provider.dart';
import 'package:gowayki_lab/app/providers/planner_providers.dart';
import 'package:gowayki_lab/app/settings/app_settings.dart';
import 'package:gowayki_lab/core/models/place_result.dart';
import 'package:gowayki_lab/domain/models/navigation_search.dart';
import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'package:gowayki_lab/domain/planner/itinerary_selection.dart';
import 'package:gowayki_lab/domain/planner/journey_planner.dart';
import 'package:gowayki_lab/domain/planner/planner_network.dart';
import 'package:gowayki_lab/domain/planner/planner_worker.dart';
import 'package:gowayki_lab/domain/repositories/journey_planner_client.dart';
import 'package:gowayki_lab/infra/city_pack/sqlite_planner_network_reader.dart';
import 'package:gowayki_lab/l10n/generated/app_localizations.dart';

class CapturingShare implements TextSharing {
  final messages = <String>[];
  @override
  Future<void> share(String text, {required Rect origin}) async {
    messages.add(text);
  }
}

class RealZoneClient implements JourneyPlannerClient {
  RealZoneClient(this.worker, this.zone);
  final PlannerWorker worker;
  final Zone zone;
  Future<JourneyResponse>? pending;
  @override
  Future<JourneyResponse> plan(JourneyRequest request, {DateTime? now}) {
    final result = zone.run<Future<JourneyResponse>>(
      () => worker.plan(request, now: now),
    );
    pending = result;
    return result;
  }

  @override
  Future<void> close() async {}
}

class ResultClient implements JourneyPlannerClient {
  ResultClient(this.response);
  JourneyResponse response;
  JourneyPlannerClient? delegate;
  final requests = <JourneyRequest>[];
  @override
  Future<JourneyResponse> plan(JourneyRequest request, {DateTime? now}) async {
    requests.add(request);
    return delegate == null
        ? response
        : await delegate!.plan(request, now: now);
  }

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = {
    'tecsup': ('osm:way:409177970', 'osm:way:437694283'),
    'plaza': ('osm:way:23811932', 'osm:way:198666186'),
    'yanahuara': ('osm:node:4262845116', 'osm:node:4126637264'),
  };
  final responses = <String, JourneyResponse>{},
      points = <String, JourneyEndpoints>{};
  final now = DateTime.utc(2026, 11, 6, 15);
  late PlannerNetwork network;
  late Zone realZone;
  late PlannerWorker worker;
  late JourneyResponse night;
  late CapturingShare sharing;
  late ProviderContainer container;
  late ResultClient client;
  late ExplorerMap map;
  setUpAll(() async {
    realZone = Zone.current;
    network = await Isolate.run(
      () => readPlannerNetwork('assets/city/arequipa/pack.sqlite'),
    );
    worker = await PlannerWorker.start(network);
    final db = sqlite3.open(
      'assets/city/arequipa/pack.sqlite',
      mode: OpenMode.readOnly,
    );
    PlaceResult place(String id) {
      final row = db.select('SELECT * FROM places WHERE place_id=?', [
        id,
      ]).single;
      return PlaceResult(
        id: id,
        name: row['name'] as String,
        address: row['address'] as String,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
      );
    }

    try {
      for (final entry in cases.entries) {
        final pair = JourneyEndpoints(
          origin: place(entry.value.$1),
          destination: place(entry.value.$2),
        );
        points[entry.key] = pair;
        responses[entry.key] = await worker.plan(
          JourneyRequest(
            origin: GeoPoint(pair.origin.latitude, pair.origin.longitude),
            destination: GeoPoint(
              pair.destination.latitude,
              pair.destination.longitude,
            ),
            time: JourneyTime.leaveAt(now),
          ),
        );
      }
    } finally {
      db.close();
    }
    final pair = points['tecsup']!;
    night = await worker.plan(
      JourneyRequest(
        origin: GeoPoint(pair.origin.latitude, pair.origin.longitude),
        destination: GeoPoint(
          pair.destination.latitude,
          pair.destination.longitude,
        ),
        time: JourneyTime.leaveAt(DateTime.utc(2026, 11, 6, 7)),
      ),
    );
  });
  tearDownAll(() async => worker.close());
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = ResultClient(responses['tecsup']!);
    sharing = CapturingShare();
    container = ProviderContainer(
      overrides: [
        textSharingProvider.overrideWithValue(sharing),
        plannerClientProvider.overrideWith((ref) async => client),
        appClockProvider.overrideWithValue(() => now),
        explorerMapRendererProvider.overrideWithValue((value) {
          map = value;
          return const ColoredBox(color: Colors.grey);
        }),
      ],
    );
    await container.read(appSettingsProvider.future);
    await container.read(localLibraryProvider.future);
    await container.read(plannerClientProvider.future);
  });
  tearDown(() => container.dispose());
  Future<void> mount(WidgetTester tester, JourneyEndpoints pair) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlannerScreen(points: pair),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final name in cases.keys) {
    testWidgets('tarjeta y mapa usan el resultado real de $name', (
      tester,
    ) async {
      client.response = responses[name]!;
      await mount(tester, points[name]!);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('itinerary.0')),
        250,
      );
      final card = tester.widget<ItineraryCard>(
        find.byKey(const ValueKey('itinerary.0')),
      );
      expect(card.trip, client.response.itineraries.first);
      expect(map.journeys.first, card.trip);
      expect(map.showStops, isFalse);
      expect(
        find.text('Caminata: ~${card.trip.walkingMinutes.round()} min'),
        findsWidgets,
      );
      expect(
        find.text(
          'Tarifa estimada: S/ ${card.trip.estimatedFare.toStringAsFixed(2)}',
        ),
        findsWidgets,
      );
      expect(
        client.requests.single.origin.latitude,
        points[name]!.origin.latitude,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
  for (final name in cases.keys) {
    testWidgets('interfaz consulta el worker real de punta a punta: $name', (
      tester,
    ) async {
      final bridge = RealZoneClient(worker, realZone);
      client.delegate = bridge;
      await mount(tester, points[name]!);
      final result = await tester.runAsync(() => bridge.pending!);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('itinerary.0')),
        250,
      );
      final card = tester.widget<ItineraryCard>(
        find.byKey(const ValueKey('itinerary.0')),
      );
      expect(result!.status, JourneyStatus.success);
      expect(
        card.trip.durationMinutes,
        closeTo(result.itineraries.first.durationMinutes, .000001),
      );
      expect(card.trip.boardings, greaterThan(0));
      expect(map.journeys.first.walkingMeters, card.trip.walkingMeters);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'detalle muestra pasos reales, guarda y comparte solo al pulsar',
    (tester) async {
      client.response = responses['yanahuara']!;
      await mount(tester, points['yanahuara']!);
      final card = find.byKey(const ValueKey('itinerary.0'));
      await tester.scrollUntilVisible(card, 250);
      final detail = find.descendant(
        of: card,
        matching: find.widgetWithText(TextButton, 'Ver detalle'),
      );
      await tester.ensureVisible(detail);
      await tester.pumpAndSettle();
      await tester.tap(detail);
      await tester.pumpAndSettle();
      expect(find.byType(ItineraryDetailScreen), findsOneWidget);
      expect(map.journeys.single, client.response.itineraries.first);
      expect(sharing.messages, isEmpty);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('trip.save')),
        300,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('trip.save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trip.save')));
      await tester.pumpAndSettle();
      final stored = container
          .read(localLibraryProvider)
          .requireValue
          .items
          .single;
      expect(stored.trip!.origin.id, points['yanahuara']!.origin.id);
      expect(find.text('Quitar viaje guardado'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('trip.share')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trip.share')));
      await tester.pumpAndSettle();
      final expected = journeyShareText(
        client.response.itineraries.first,
        points['yanahuara']!,
        AppLocalizationsEs(),
      );
      expect(sharing.messages, [expected]);
      expect(expected, contains('Camina ~'));
      expect(expected, contains('Pasa cada ~'));
      expect(expected, contains('Viaja '));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'orden y evitar transbordos se pasan al cliente sin cambiar puntos',
    (tester) async {
      await mount(tester, points['tecsup']!);
      await tester.tap(find.byKey(const ValueKey('planner.order')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Menos transbordos').last);
      await tester.pumpAndSettle();
      expect(client.requests.last.order, JourneyOrder.fewestTransfers);
      await container
          .read(appSettingsProvider.notifier)
          .save((s) => s.copyWith(avoidTransfers: true));
      await tester.pumpAndSettle();
      expect(client.requests.last.maxBoardings, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('noche muestra sin servicio sin inventar vehículos', (
    tester,
  ) async {
    client.response = night;
    await mount(tester, points['tecsup']!);
    await tester.scrollUntilVisible(
      find.text('Sin servicio en la hora elegida'),
      250,
    );
    expect(map.journeys.every((trip) => trip.boardings == 0), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'cliente real aplica límite peatonal y se reemplaza al cambiarlo',
    () async {
      SharedPreferences.setMockInitialValues({
        SettingsController.storageKey: const AppSettings(
          maxAccessMeters: 400,
        ).encode(),
      });
      final scope = ProviderContainer(
        overrides: [
          plannerNetworkProvider.overrideWith((ref) async => network),
        ],
      );
      JourneyPlannerClient? first, second;
      try {
        await scope.read(appSettingsProvider.future);
        first = await scope.read<Future<JourneyPlannerClient>>(
          plannerClientProvider.future,
        );
        final pair = points['tecsup']!;
        final request = JourneyRequest(
          origin: GeoPoint(pair.origin.latitude, pair.origin.longitude),
          destination: GeoPoint(
            pair.destination.latitude,
            pair.destination.longitude,
          ),
          time: JourneyTime.leaveAt(now),
        );
        final response = await first.plan(request);
        expect(response.accessRadiusMeters, 400);
        await scope
            .read(appSettingsProvider.notifier)
            .save((s) => s.copyWith(maxAccessMeters: 800));
        second = await scope.read<Future<JourneyPlannerClient>>(
          plannerClientProvider.future,
        );
        expect(identical(first, second), isFalse);
        expect((await second.plan(request)).accessRadiusMeters, 800);
        await expectLater(first.plan(request), throwsStateError);
      } finally {
        scope.dispose();
        await first?.close();
        await second?.close();
      }
    },
  );
}
