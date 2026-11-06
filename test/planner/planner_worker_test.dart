import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/domain/planner/journey_planner.dart';
import 'package:gowayki_lab/domain/planner/planner_worker.dart';
import 'toy_network.dart';

void main() {
  test(
    'reuses one isolate, correlates concurrent requests and closes resources',
    () async {
      final network = toy();
      final q = query(network);
      final worker = await PlannerWorker.start(network);
      try {
        final result = await Future.wait([
          worker.plan(
            JourneyRequest(
              origin: q.origin,
              destination: q.destination,
              time: JourneyTime.leaveAt(at(10)),
            ),
          ),
          worker.plan(
            JourneyRequest(
              origin: q.origin,
              destination: q.destination,
              time: JourneyTime.arriveBy(at(10, 49)),
            ),
          ),
        ]);
        expect(result[0].itineraries.first.arrivalAt, at(10, 49));
        expect(result[1].itineraries.first.departureAt, at(10));
      } finally {
        await worker.close();
      }
      await worker.close();
      await expectLater(
        worker.plan(
          JourneyRequest(
            origin: q.origin,
            destination: q.destination,
            time: const JourneyTime.now(),
          ),
        ),
        throwsStateError,
      );
    },
  );
}
