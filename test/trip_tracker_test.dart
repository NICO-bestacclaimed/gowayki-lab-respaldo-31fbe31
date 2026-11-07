import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'package:gowayki_lab/domain/models/city_pack_models.dart';
import 'package:gowayki_lab/domain/repositories/position_repository.dart';
import 'package:gowayki_lab/domain/tracking/trip_tracker.dart';

final epoch = DateTime.utc(2026, 11, 7, 15);
GeoPoint point(double meters) => GeoPoint(meters / 111195.08, 0);
CityStop stop(String name, double meters) => CityStop(
  id: name,
  name: name,
  latitude: point(meters).latitude,
  longitude: 0,
  sourceKind: 'test',
  nameSource: 'test',
  needsReview: false,
  usedInPatterns: true,
);
TransitLeg bus({
  double from = 0,
  double to = 1000,
  List<double> stops = const [300, 900],
  List<GeoPoint>? geometry,
}) => TransitLeg(
  lineId: 'test',
  lineName: 'Test',
  color: '#ff5500',
  patternId: 'test',
  direction: '0',
  headsign: 'Test',
  boardingStop: stop('A', from),
  alightingStop: stop('B', to),
  intermediateStops: [for (final m in stops) stop('$m', m)],
  boardingAt: epoch,
  expectedWaitMinutes: 3,
  fare: const CityFare(amount: 1, currency: 'PEN'),
  geometry: geometry ?? [point(from), point(to)],
  departureAt: epoch,
  arrivalAt: epoch.add(const Duration(minutes: 10)),
);
WalkLeg walk(double from, double to) => WalkLeg(
  from: point(from),
  to: point(to),
  meters: (to - from).abs(),
  departureAt: epoch,
  arrivalAt: epoch.add(const Duration(minutes: 2)),
);
Itinerary itinerary(List<JourneyLeg> legs) => Itinerary(
  departureAt: epoch,
  arrivalAt: epoch.add(const Duration(minutes: 20)),
  legs: legs,
);
PositionFix fix(double meters, int seconds, {double accuracy = 5}) =>
    PositionFix(
      point: point(meters),
      accuracyMeters: accuracy,
      at: epoch.add(Duration(seconds: seconds)),
    );
TripProgress feed(
  TripTracker tracker,
  double meters,
  int seconds, {
  double accuracy = 5,
}) => tracker.update(
  fix(meters, seconds, accuracy: accuracy),
  now: epoch.add(Duration(seconds: seconds)),
);

void main() {
  test(
    'walking near a route never arms the alighting alert until boarding is confirmed',
    () {
      final tracker = TripTracker(itinerary([bus()]));
      expect(feed(tracker, 650, 0).phase, TripPhase.waitingToBoard);
      expect(feed(tracker, 950, 5).alerts, isEmpty);
      expect(tracker.confirmStep().phase, TripPhase.riding);
    },
  );
  test('400 meter threshold follows geometry and emits once', () {
    final tracker = TripTracker(itinerary([bus()]))..confirmStep();
    expect(feed(tracker, 200, 0).alerts, isEmpty);
    expect(feed(tracker, 590, 20).alerts, isEmpty);
    final near = feed(tracker, 610, 25);
    expect(near.remainingMeters, closeTo(390, 1));
    expect(near.alerts.single.kind, TripAlertKind.alight);
    expect(feed(tracker, 650, 30).alerts, isEmpty);
  });
  test('last remaining stop triggers even before 400 meters', () {
    final tracker = TripTracker(
      itinerary([
        bus(stops: [500]),
      ]),
    )..confirmStep();
    feed(tracker, 200, 0);
    final near = feed(tracker, 510, 20);
    expect(near.remainingMeters, greaterThan(400));
    expect(near.stopsRemaining, 1);
    expect(near.alerts.single.kind, TripAlertKind.alight);
  });
  test(
    'imprecise, stale, future and out-of-order fixes cannot trigger alerts',
    () {
      final tracker = TripTracker(itinerary([bus()]))..confirmStep();
      feed(tracker, 200, 0);
      expect(feed(tracker, 650, 20, accuracy: 100).alerts, isEmpty);
      expect(
        tracker
            .update(fix(650, 20), now: epoch.add(const Duration(seconds: 60)))
            .alerts,
        isEmpty,
      );
      expect(tracker.update(fix(650, 60), now: epoch).alerts, isEmpty);
      feed(tracker, 400, 20);
      expect(feed(tracker, 700, 10).alerts, isEmpty);
    },
  );
  test('GPS away from the selected route cannot advance or alert', () {
    final tracker = TripTracker(itinerary([bus()]))..confirmStep();
    final progress = tracker.update(
      PositionFix(
        point: GeoPoint(point(650).latitude, .01),
        accuracyMeters: 5,
        at: epoch,
      ),
      now: epoch,
    );
    expect(progress.offRoute, isTrue);
    expect(progress.alerts, isEmpty);
    expect(progress.phase, TripPhase.riding);
  });
  test(
    'geometry crossing near the destination does not finish a loop prematurely',
    () {
      final a = point(0), b = point(1000);
      final tracker = TripTracker(
        itinerary([
          bus(
            to: 10,
            stops: [],
            geometry: [
              a,
              b,
              GeoPoint(b.latitude, .01),
              GeoPoint(0, .01),
              point(10),
            ],
          ),
        ]),
      )..confirmStep();
      final progress = feed(tracker, 10, 0);
      expect(progress.phase, TripPhase.riding);
      expect(progress.remainingMeters, greaterThan(4000));
      expect(progress.alerts, isEmpty);
    },
  );
  test(
    'arrival at transfer zone advances once and requires boarding again',
    () {
      final tracker = TripTracker(
        itinerary([
          bus(),
          walk(1000, 1100),
          bus(from: 1100, to: 2100, stops: []),
        ]),
      )..confirmStep();
      feed(tracker, 200, 0);
      feed(tracker, 650, 20);
      final arrived = feed(tracker, 970, 40);
      expect(arrived.legIndex, 1);
      expect(arrived.phase, TripPhase.walking);
      expect(arrived.alerts.single.kind, TripAlertKind.transfer);
      final boarding = feed(tracker, 1090, 50);
      expect(boarding.phase, TripPhase.waitingToBoard);
      expect(boarding.alerts, isEmpty);
    },
  );
  test(
    'final walking arrival ends the journey; later samples do not restart it',
    () {
      final tracker = TripTracker(itinerary([walk(0, 200)]));
      expect(feed(tracker, 0, 0).phase, TripPhase.walking);
      expect(feed(tracker, 170, 20).phase, TripPhase.completed);
      expect(feed(tracker, 0, 30).phase, TripPhase.completed);
    },
  );
  test(
    'tracking recovers after a long GPS gap using elapsed travel bounds',
    () {
      final tracker = TripTracker(
        itinerary([
          bus(to: 3000, stops: [2900]),
        ]),
      )..confirmStep();
      feed(tracker, 200, 0);
      final recovered = feed(tracker, 2610, 120);
      expect(recovered.offRoute, isFalse);
      expect(recovered.remainingMeters, closeTo(390, 1));
      expect(recovered.phase, TripPhase.riding);
      expect(recovered.alerts.single.kind, TripAlertKind.alight);
    },
  );
  test('manual confirmation advances when GPS is unavailable', () {
    final tracker = TripTracker(
      itinerary([walk(0, 100), bus(), walk(1000, 1100)]),
    );
    expect(tracker.confirmStep().phase, TripPhase.waitingToBoard);
    expect(tracker.confirmStep().phase, TripPhase.riding);
    expect(tracker.confirmStep().phase, TripPhase.walking);
    expect(tracker.confirmStep().phase, TripPhase.completed);
  });
}
