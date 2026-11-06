import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/domain/planner/journey_planner.dart';
import 'package:gowayki_lab/domain/planner/raptor_planner.dart';

import 'toy_network.dart';

void main() {
  test(
    'leave now uses the supplied clock and leave at uses the exact instant',
    () {
      final network = toy();
      final q = query(network);
      final planner = JourneyPlanner(network);
      JourneyRequest request(JourneyTime time) => JourneyRequest(
        origin: q.origin,
        destination: q.destination,
        time: time,
      );
      final now = planner.plan(request(const JourneyTime.now()), now: at(10));
      final explicit = planner.plan(
        request(JourneyTime.leaveAt(at(10))),
        now: at(20),
      );
      expect(now.status, JourneyStatus.success);
      expect(explicit.itineraries.first.arrivalAt, at(10, 49));
      expect(
        now.itineraries.first.arrivalAt,
        explicit.itineraries.first.arrivalAt,
      );
    },
  );

  test(
    'arrive by meets its deadline and obtains the latest whole-second departure',
    () {
      final network = toy();
      final q = query(network);
      final response = JourneyPlanner(network).plan(
        JourneyRequest(
          origin: q.origin,
          destination: q.destination,
          time: JourneyTime.arriveBy(at(10, 49)),
        ),
      );
      expect(response.status, JourneyStatus.success);
      final best = response.itineraries.first;
      expect(best.departureAt, at(10));
      expect(best.arrivalAt, at(10, 49));
      final later = RaptorPlanner(network).plan(
        PlannerQuery(
          origin: q.origin,
          destination: q.destination,
          departureAt: best.departureAt.add(const Duration(seconds: 1)),
        ),
      );
      expect(
        later.itineraries.every((trip) => trip.arrivalAt.isAfter(at(10, 49))),
        isTrue,
      );
    },
  );

  test(
    'reverse search also meets a deadline across changing speed and frequency bands',
    () {
      final network = toy();
      final q = query(network, end: 'B', departure: at(6, 50));
      final planner = JourneyPlanner(network);
      for (final deadline in [
        at(7, 10),
        at(9, 5),
        at(12, 15),
        at(17, 15),
        at(20, 15),
      ]) {
        final result = planner.plan(
          JourneyRequest(
            origin: q.origin,
            destination: q.destination,
            time: JourneyTime.arriveBy(deadline),
          ),
        );
        expect(result.status, JourneyStatus.success);
        expect(
          result.itineraries.every((trip) => !trip.arrivalAt.isAfter(deadline)),
          isTrue,
        );
      }
    },
  );

  test(
    'night is explicitly no-service and an unreachable area is no-route',
    () {
      final network = toy();
      final q = query(network);
      final planner = JourneyPlanner(network);
      for (final time in [at(23), at(3), at(4, 59)]) {
        final result = planner.plan(
          JourneyRequest(
            origin: q.origin,
            destination: q.destination,
            time: JourneyTime.leaveAt(time),
          ),
        );
        expect(result.status, JourneyStatus.noService);
        expect(result.itineraries, isEmpty);
      }
      final unreachable = query(network, entry: 2000);
      final result = planner.plan(
        JourneyRequest(
          origin: unreachable.origin,
          destination: unreachable.destination,
          time: JourneyTime.leaveAt(at(10)),
        ),
      );
      expect(result.status, JourneyStatus.noRoute);
    },
  );

  test(
    'arrive by after closure finds a valid earlier trip and never adds overnight vehicle time',
    () {
      final network = toy();
      final q = query(network, end: 'B');
      final result = JourneyPlanner(network).plan(
        JourneyRequest(
          origin: q.origin,
          destination: q.destination,
          time: JourneyTime.arriveBy(at(23, 15)),
        ),
      );
      expect(result.status, JourneyStatus.success);
      expect(
        result.itineraries.every((trip) => !trip.arrivalAt.isAfter(at(23, 15))),
        isTrue,
      );
      expect(result.itineraries.first.departureAt.isBefore(at(23)), isTrue);
      expect(result.itineraries.first.vehicleMinutes, greaterThan(0));
    },
  );

  test('inverse travel matches forward travel across boundaries', () {
    final s = configured();
    for (final departure in [at(6, 58), at(8, 59), at(11, 59), at(19, 59)]) {
      final arrival = s.travel(departure, 3000)!;
      final backwards = s.travelBackwards(arrival, 3000)!;
      expect(
        backwards.difference(departure).inMicroseconds.abs(),
        lessThanOrEqualTo(2),
      );
    }
  });

  test('requested time computation runs in an isolate', () async {
    final network = toy();
    final q = query(network);
    final result = await planJourneyInIsolate(
      network,
      JourneyRequest(
        origin: q.origin,
        destination: q.destination,
        time: JourneyTime.arriveBy(at(10, 49)),
      ),
    );
    expect(result.itineraries.first.arrivalAt, at(10, 49));
  });
}
