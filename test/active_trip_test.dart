import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowayki_lab/app/providers/active_trip_provider.dart';
import 'package:gowayki_lab/app/providers/start_trip_provider.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/providers/location_providers.dart';
import 'package:gowayki_lab/app/providers/location_ownership_provider.dart';
import 'package:gowayki_lab/app/providers/map_renderer_provider.dart';
import 'package:gowayki_lab/app/features/active_trip/active_trip_screen.dart';
import 'package:gowayki_lab/app/settings/app_settings.dart';
import 'package:gowayki_lab/core/models/place_result.dart';
import 'package:gowayki_lab/domain/models/navigation_search.dart';
import 'package:gowayki_lab/domain/repositories/trip_tracking_repository.dart';
import 'package:gowayki_lab/domain/repositories/position_repository.dart';
import 'package:gowayki_lab/infra/notifications/trip_notifications.dart';
import 'package:gowayki_lab/l10n/generated/app_localizations_es.dart';
import 'location_provider_test.dart' show Permission, Positions;
import 'trip_tracker_test.dart' as fixture;

class Tracking implements TripTrackingRepository {
  @override
  bool get supported => true;
  int starts = 0, cancels = 0;
  late final stream = StreamController<PositionFix>.broadcast(
    onCancel: () => cancels++,
  );
  @override
  Stream<PositionFix> watch({required String title, required String body}) {
    starts++;
    expect(title, 'GoWayki · Viaje en curso');
    return stream.stream;
  }
}

class Notifications implements TripNotifications {
  int clears = 0;
  final modes = <AlarmMode>[];
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> alert({
    required String title,
    required String body,
    required AlarmMode mode,
  }) async {
    modes.add(mode);
  }

  @override
  Future<void> clear() async {
    clears++;
  }
}

const points = JourneyEndpoints(
  origin: PlaceResult(
    id: 'A',
    name: 'A',
    address: '',
    latitude: 0,
    longitude: 0,
  ),
  destination: PlaceResult(
    id: 'B',
    name: 'B',
    address: '',
    latitude: .01,
    longitude: 0,
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Tracking tracking;
  late Notifications notifications;
  late Positions positions;
  late Permission permissions;
  late ProviderContainer container;
  var now = fixture.epoch;
  var visible = true;
  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> sample(double meters, int seconds) async {
    now = fixture.epoch.add(Duration(seconds: seconds));
    tracking.stream.add(fixture.fix(meters, seconds));
    await flush();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tracking = Tracking();
    notifications = Notifications();
    positions = Positions();
    permissions = Permission();
    now = fixture.epoch;
    visible = true;
    container = ProviderContainer(
      overrides: [
        tripTrackingRepositoryProvider.overrideWithValue(tracking),
        tripNotificationsProvider.overrideWithValue(notifications),
        positionRepositoryProvider.overrideWithValue(positions),
        locationPermissionRepositoryProvider.overrideWithValue(permissions),
        tripClockProvider.overrideWithValue(() => now),
        tripCanStartProvider.overrideWithValue(() => visible),
        explorerMapRendererProvider.overrideWithValue(
          (map) => const ColoredBox(color: Colors.orange),
        ),
      ],
    );
    await container.read(appSettingsProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await flush();
    await tracking.stream.close();
    await positions.stream.close();
  });
  test(
    'starting takes exclusive location ownership; stopping cancels service and clears alerts',
    () async {
      await container.read(explorerLocationProvider.notifier).start();
      final active = container.read(activeTripProvider.notifier);
      await active.start(
        fixture.itinerary([fixture.bus()]),
        points,
        AppLocalizationsEs(),
      );
      expect(positions.cancels, 1);
      expect(tracking.starts, 1);
      expect(container.read(tripOwnsLocationProvider), isTrue);
      await active.stop();
      expect(tracking.cancels, 1);
      expect(notifications.clears, 1);
      expect(container.read(tripOwnsLocationProvider), isFalse);
      expect(
        container.read(activeTripProvider)!.status,
        ActiveTripStatus.stopped,
      );
    },
  );
  for (final mode in AlarmMode.values) {
    test(
      'alighting uses current ${mode.name} setting and does not repeat',
      () async {
        await container
            .read(appSettingsProvider.notifier)
            .save((s) => s.copyWith(alarm: mode));
        final active = container.read(activeTripProvider.notifier);
        await active.start(
          fixture.itinerary([fixture.bus()]),
          points,
          AppLocalizationsEs(),
        );
        active.confirmStep();
        await sample(200, 0);
        await sample(650, 20);
        await sample(700, 25);
        expect(notifications.modes, mode == AlarmMode.off ? isEmpty : [mode]);
        await active.stop();
      },
    );
  }
  test('arrival automatically stops GPS and service', () async {
    final active = container.read(activeTripProvider.notifier);
    await active.start(
      fixture.itinerary([fixture.walk(0, 200)]),
      points,
      AppLocalizationsEs(),
    );
    await sample(180, 0);
    await flush();
    expect(
      container.read(activeTripProvider)!.status,
      ActiveTripStatus.completed,
    );
    expect(tracking.cancels, 1);
    expect(container.read(tripOwnsLocationProvider), isFalse);
  });
  test('stream errors stop tracking and release the service', () async {
    final active = container.read(activeTripProvider.notifier);
    await active.start(
      fixture.itinerary([fixture.bus()]),
      points,
      AppLocalizationsEs(),
    );
    tracking.stream.addError(StateError('GPS lost'));
    await flush();
    expect(container.read(activeTripProvider)!.status, ActiveTripStatus.error);
    expect(tracking.cancels, 1);
    expect(container.read(tripOwnsLocationProvider), isFalse);
  });
  test('a concurrent double start creates only one service', () async {
    final active = container.read(activeTripProvider.notifier);
    final first = active.start(
      fixture.itinerary([fixture.bus()]),
      points,
      AppLocalizationsEs(),
    );
    final second = active.start(
      fixture.itinerary([fixture.bus()]),
      points,
      AppLocalizationsEs(),
    );
    await expectLater(second, throwsStateError);
    await first;
    expect(tracking.starts, 1);
    await active.stop();
  });
  test('GPS disabled prevents service start', () async {
    positions.enabled = false;
    await expectLater(
      container
          .read(activeTripProvider.notifier)
          .start(
            fixture.itinerary([fixture.bus()]),
            points,
            AppLocalizationsEs(),
          ),
      throwsStateError,
    );
    expect(tracking.starts, 0);
    expect(container.read(tripOwnsLocationProvider), isFalse);
  });
  test('background start is rejected before subscribing to location', () async {
    visible = false;
    await expectLater(
      container
          .read(activeTripProvider.notifier)
          .start(
            fixture.itinerary([fixture.bus()]),
            points,
            AppLocalizationsEs(),
          ),
      throwsStateError,
    );
    expect(tracking.starts, 0);
    expect(container.read(tripOwnsLocationProvider), isFalse);
  });
  testWidgets(
    'start disclosure can be cancelled without requesting permissions',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) => Scaffold(
                body: FilledButton(
                  onPressed: () {
                    ref.read(startTripActionProvider)!(
                      context,
                      fixture.itinerary([fixture.bus()]),
                      points,
                    );
                  },
                  child: const Text('Start'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Android mostrará una notificación persistente'),
        findsOneWidget,
      );
      expect(permissions.requests, 0);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tracking.starts, 0);
      expect(container.read(activeTripProvider), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('active screen shows real step, distance and manual boarding', (
    tester,
  ) async {
    final active = container.read(activeTripProvider.notifier);
    await tester.runAsync(
      () => active.start(
        fixture.itinerary([fixture.bus()]),
        points,
        AppLocalizationsEs(),
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ActiveTripScreen()),
      ),
    );
    expect(find.text('Espera y sube a Test'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('active.confirm')));
    await tester.tap(find.byKey(const ValueKey('active.confirm')));
    await tester.pump();
    expect(find.text('Continúa en Test'), findsOneWidget);
    await tester.runAsync(() => sample(200, 0));
    await tester.pump();
    expect(find.byKey(const ValueKey('active.distance')), findsOneWidget);
    await tester.runAsync(active.stop);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
