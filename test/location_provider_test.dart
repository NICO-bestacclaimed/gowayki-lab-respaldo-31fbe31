import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/providers/location_providers.dart';
import 'package:gowayki_lab/domain/repositories/location_permission_repository.dart';
import 'package:gowayki_lab/domain/repositories/position_repository.dart';
import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'package:gowayki_lab/app/features/explorer/map/nearby_stops.dart';
import 'package:gowayki_lab/domain/models/city_pack_models.dart';

class Permission implements LocationPermissionRepository {
  LocationAccess access = LocationAccess.allowed;
  int requests = 0;
  @override
  Future<LocationAccess> check() async => access;
  @override
  Future<LocationAccess> request() async {
    requests++;
    return access;
  }

  @override
  Future<bool> openSettings() async => true;
}

class Positions implements PositionRepository {
  bool enabled = true;
  int reads = 0, cancels = 0;
  late final StreamController<PositionFix> stream = StreamController.broadcast(
    onCancel: () => cancels++,
  );
  Completer<PositionFix>? pending;
  PositionFix fix = PositionFix(
    point: GeoPoint(-16.4, -71.5),
    accuracyMeters: 8,
    at: DateTime.utc(2026, 11, 6),
    heading: 90,
  );
  @override
  Future<bool> serviceEnabled() async => enabled;
  @override
  Future<PositionFix> current() {
    reads++;
    return pending?.future ?? Future.value(fix);
  }

  @override
  Stream<PositionFix> watch() => stream.stream;
  @override
  Future<bool> openServiceSettings() async => true;
}

void main() {
  late Permission permission;
  late Positions positions;
  late ProviderContainer container;
  setUp(() {
    permission = Permission();
    positions = Positions();
    container = ProviderContainer(
      overrides: [
        locationPermissionRepositoryProvider.overrideWithValue(permission),
        positionRepositoryProvider.overrideWithValue(positions),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await positions.stream.close();
  });
  test(
    'permiso y GPS se comprueban sin pedir acceso automáticamente',
    () async {
      permission.access = LocationAccess.denied;
      final controller = container.read(explorerLocationProvider.notifier);
      await controller.start();
      expect(
        container.read(explorerLocationProvider).status,
        LocationStatus.permission,
      );
      expect(permission.requests, 0);
      expect(positions.reads, 0);
      permission.access = LocationAccess.allowed;
      positions.enabled = false;
      await controller.start(refresh: true);
      expect(
        container.read(explorerLocationProvider).status,
        LocationStatus.gpsOff,
      );
      expect(positions.reads, 0);
    },
  );
  test(
    'posición y rumbo reales se actualizan, stop cancela el stream',
    () async {
      final controller = container.read(explorerLocationProvider.notifier);
      await controller.start();
      expect(container.read(explorerLocationProvider).fix!.heading, 90);
      positions.stream.add(
        PositionFix(
          point: GeoPoint(-16.41, -71.51),
          accuracyMeters: 9,
          at: DateTime.utc(2026, 11, 6),
          heading: 180,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(explorerLocationProvider).fix!.heading, 180);
      await controller.stop();
      expect(positions.cancels, 1);
      expect(
        container.read(explorerLocationProvider).status,
        LocationStatus.idle,
      );
    },
  );
  test(
    'una lectura pendiente no revive el seguimiento después de stop',
    () async {
      positions.pending = Completer();
      final controller = container.read(explorerLocationProvider.notifier);
      final loading = controller.start();
      await Future<void>.delayed(Duration.zero);
      await controller.stop();
      positions.pending!.complete(positions.fix);
      await loading;
      expect(
        container.read(explorerLocationProvider).status,
        LocationStatus.idle,
      );
      expect(positions.stream.hasListener, isFalse);
    },
  );
  test('distancia a pie usa factor estimado y orden real', () {
    CityMapStop entry(String id, double latitude) => CityMapStop(
      stop: CityStop(
        id: id,
        name: id,
        latitude: latitude,
        longitude: -71.5,
        sourceKind: 'gtfs_candidate',
        nameSource: 'source',
        needsReview: false,
        usedInPatterns: true,
      ),
      services: const [],
    );
    final nearby = nearbyStops([
      entry('far', -16.41),
      entry('near', -16.4001),
      entry('outside', -17),
    ], GeoPoint(-16.4, -71.5));
    expect(nearby.map((s) => s.entry.stop.id), ['near', 'far']);
    expect(nearby.first.walkMeters, closeTo(14.46, .1));
  });
}
