import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/domain/models/city_pack_models.dart';
import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'package:gowayki_lab/domain/planner/itinerary_selection.dart';
import 'package:gowayki_lab/domain/planner/journey_planner.dart';
import 'package:gowayki_lab/domain/planner/planner_network.dart';
import 'package:gowayki_lab/domain/planner/raptor_planner.dart';
import 'package:gowayki_lab/domain/planner/service_schedule.dart';

import 'toy_network.dart';

Itinerary synthetic(
  String id,
  double minutes,
  double meters, {
  int boardings = 1,
}) {
  final a = stop('a', 0), b = stop('b', 1000);
  final start = at(10);
  var time = addMinutes(start, meters / 75);
  final legs = <JourneyLeg>[
    WalkLeg(
      from: point(0),
      to: point(0),
      meters: meters,
      departureAt: start,
      arrivalAt: time,
    ),
  ];
  final vehicle = (minutes - meters / 75 - boardings * 3) / boardings;
  for (var i = 0; i < boardings; i++) {
    final boarding = addMinutes(time, 3), end = addMinutes(boarding, vehicle);
    legs.add(
      TransitLeg(
        lineId: '$id-$i',
        lineName: id,
        color: '#123456',
        patternId: '$id-$i',
        direction: 'ida',
        headsign: 'b',
        boardingStop: a,
        alightingStop: b,
        intermediateStops: [],
        boardingAt: boarding,
        expectedWaitMinutes: 3,
        fare: const CityFare(amount: 1, currency: 'PEN'),
        geometry: [point(0), point(1000)],
        departureAt: time,
        arrivalAt: end,
      ),
    );
    time = end;
  }
  return Itinerary(departureAt: start, arrivalAt: time, legs: legs);
}

void main() {
  test(
    'keeps time/walking tradeoffs, removes dominated routes and sorts by preference',
    () {
      final stops = {
        'A': stop('A', 0),
        'P': stop('P', 500),
        'B': stop('B', 1000),
      };
      final slow = pattern('slow', ['A', 'B'], [0, 5000], stops);
      final fast = pattern('fast', ['P', 'B'], [0, 500], stops);
      final dominated = pattern('dominated', ['P', 'B'], [0, 600], stops);
      final duplicate = PlannerPattern(
        id: 'duplicate',
        lineId: fast.lineId,
        lineName: fast.lineName,
        color: fast.color,
        direction: fast.direction,
        headsign: fast.headsign,
        visits: fast.visits,
        shape: fast.shape,
        fare: fast.fare,
      );
      final network = PlannerNetwork(
        stops: stops,
        patterns: [slow, fast, dominated, duplicate],
        transfers: {},
        settings: configured(),
      );
      JourneyRequest request(JourneyOrder order) => JourneyRequest(
        origin: point(0),
        destination: point(1000),
        time: JourneyTime.leaveAt(at(10)),
        order: order,
      );
      final planner = JourneyPlanner(network);
      final fastest = planner.plan(request(JourneyOrder.fastest));
      expect(fastest.itineraries, hasLength(2));
      expect(
        fastest.itineraries.first.legs.whereType<TransitLeg>().single.lineId,
        'fast',
      );
      expect(
        planner
            .plan(request(JourneyOrder.leastWalking))
            .itineraries
            .first
            .legs
            .whereType<TransitLeg>()
            .single
            .lineId,
        'slow',
      );
      expect(
        fastest.itineraries.any(
          (p) => p.legs.whereType<TransitLeg>().any(
            (leg) => leg.lineId == 'dominated',
          ),
        ),
        isFalse,
      );
      expect(fastest.walkingAlternative, isNotNull);
      expect(fastest.walkingAlternative!.walkingMeters, closeTo(1300, .000001));
      expect(fastest.walkingAlternative!.estimatedFare, 0);
      expect(fastest.walkingAlternative!.currency, 'PEN');
    },
  );

  test(
    'preserves a slower low-walking label at an intermediate stop for a later connection',
    () {
      final stops = {
        'A': stop('A', 0),
        'P': stop('P', 500),
        'X': stop('X', 3000),
        'Y': stop('Y', 5000),
      };
      final network = PlannerNetwork(
        stops: stops,
        patterns: [
          pattern('lowWalk', ['A', 'X'], [0, 9000], stops),
          pattern('fast', ['P', 'X'], [0, 2500], stops),
          pattern('last', ['X', 'Y'], [0, 2000], stops),
        ],
        transfers: {},
        settings: configured(),
      );
      final result = RaptorPlanner(network).plan(
        PlannerQuery(
          origin: point(0),
          destination: point(5000),
          departureAt: at(10),
        ),
      );
      expect(result.itineraries, hasLength(2));
      expect(
        result.itineraries.any((trip) => trip.walkingMeters < .000001),
        isTrue,
      );
      expect(
        result.itineraries.any((trip) => trip.walkingMeters > 600),
        isTrue,
      );
      expect(result.itineraries.every((trip) => trip.transfers == 1), isTrue);
    },
  );

  test(
    'returns up to five unique line combinations from a nondominated frontier',
    () {
      final choices = [
        for (var i = 0; i < 7; i++)
          synthetic('route$i', 60 - i * 2, 100 + i * 100),
        synthetic('dominated', 80, 1000),
        synthetic('route0', 60, 100),
      ];
      final selected = selectItineraries(choices, JourneyOrder.fastest);
      expect(selected, hasLength(5));
      expect(selected.map(lineCombination).toSet(), hasLength(5));
      for (final a in selected) {
        expect(choices.any((b) => itineraryDominates(b, a)), isFalse);
      }
      expect(selected.first.durationMinutes, closeTo(48, .000001));
      expect(
        selectItineraries(
          choices,
          JourneyOrder.leastWalking,
        ).first.walkingMeters,
        100,
      );
      expect(
        () => selectItineraries(choices, JourneyOrder.fastest, limit: 6),
        throwsRangeError,
      );
    },
  );

  test('fewest transfers uses its own primary ordering criterion', () {
    final direct = synthetic('direct', 60, 500);
    final change = synthetic('change', 40, 100, boardings: 2);
    final selected = selectItineraries([
      change,
      direct,
    ], JourneyOrder.fewestTransfers);
    expect(selected.first.transfers, 0);
    expect(
      selectItineraries([change, direct], JourneyOrder.fastest).first.transfers,
      1,
    );
  });

  test(
    'walking remains available at night and arrive-by walking meets the deadline',
    () {
      final network = toy();
      final planner = JourneyPlanner(network);
      final night = planner.plan(
        JourneyRequest(
          origin: point(0),
          destination: point(1000),
          time: JourneyTime.leaveAt(at(23)),
        ),
      );
      expect(night.status, JourneyStatus.noService);
      expect(night.itineraries, isEmpty);
      expect(night.walkingAlternative!.transfers, 0);
      final arrival = planner.plan(
        JourneyRequest(
          origin: point(0),
          destination: point(1000),
          time: JourneyTime.arriveBy(at(10)),
        ),
      );
      expect(arrival.walkingAlternative!.arrivalAt, at(10));
      final long = planner.plan(
        JourneyRequest(
          origin: point(0),
          destination: point(3000),
          time: JourneyTime.leaveAt(at(10)),
        ),
      );
      expect(long.walkingAlternative, isNull);
    },
  );
}
