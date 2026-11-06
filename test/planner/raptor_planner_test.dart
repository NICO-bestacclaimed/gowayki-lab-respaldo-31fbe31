import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'package:gowayki_lab/domain/planner/planner_network.dart';
import 'package:gowayki_lab/domain/planner/raptor_planner.dart';
import 'package:gowayki_lab/domain/planner/service_schedule.dart';

import 'toy_network.dart';

void main() {
  test(
    'three-line hand calculation: 8 walking + 15 waiting + 26 riding = 49 minutes',
    () {
      final network = toy();
      final result = RaptorPlanner(network).plan(query(network));
      expect(result.accessRadiusMeters, 800);
      final itinerary = result.itineraries.first;
      expect(itinerary.durationMinutes, closeTo(49, .000001));
      expect(itinerary.arrivalAt, at(10, 49));
      expect(itinerary.walkingMinutes, closeTo(8, .000001));
      expect(itinerary.walkingMeters, closeTo(600, .000001));
      expect(itinerary.waitingMinutes, 15);
      expect(itinerary.vehicleMinutes, 26);
      expect(itinerary.estimatedFare, 3);
      expect(itinerary.currency, 'PEN');
      expect(itinerary.transfers, 2);
      expect(itinerary.boardings, 3);
      final rides = itinerary.legs.whereType<TransitLeg>().toList();
      expect(rides.map((r) => r.lineId), ['R1', 'R2', 'R3']);
      expect(rides.first.intermediateStops.single.id, 'M');
      expect(rides.first.stopCount, 2);
      expect(rides.first.boardingAt, at(10, 7));
      for (var i = 1; i < itinerary.legs.length; i++) {
        expect(itinerary.legs[i].departureAt, itinerary.legs[i - 1].arrivalAt);
      }
      expect(
        itinerary.walkingMinutes +
            itinerary.waitingMinutes +
            itinerary.vehicleMinutes,
        closeTo(itinerary.durationMinutes, .000001),
      );
    },
  );

  test('one line has no transfer and adds access/egress and one fare', () {
    final network = toy();
    final best = RaptorPlanner(
      network,
    ).plan(query(network, end: 'B')).itineraries.first;
    expect(best.durationMinutes, closeTo(19, .000001));
    expect(best.transfers, 0);
    expect(best.estimatedFare, 1);
    expect(
      best.legs.whereType<TransitLeg>().single.lineName,
      'Línea de prueba R1',
    );
  });

  test(
    'never adds a fourth boarding and two rounds cannot complete three lines',
    () {
      final network = toy(fourth: true);
      expect(
        RaptorPlanner(
          network,
        ).plan(query(network, maxBoardings: 2)).itineraries,
        isEmpty,
      );
      expect(
        RaptorPlanner(network).plan(query(network, end: 'G')).itineraries,
        isEmpty,
      );
      expect(() => query(network, maxBoardings: 4), throwsRangeError);
    },
  );

  test(
    'expands 800 to 1500 walking meters only when the first search has no result',
    () {
      final network = toy();
      final result = RaptorPlanner(network).plan(query(network, entry: 900));
      expect(result.accessRadiusMeters, 1500);
      expect(result.itineraries.first.durationMinutes, closeTo(59, .000001));
      expect(
        RaptorPlanner(network).plan(query(network, entry: 1501)).itineraries,
        isEmpty,
      );
    },
  );

  test('line-specific fare and peak waiting/speed are used', () {
    final network = toy(secondFare: 1.5);
    expect(
      RaptorPlanner(
        network,
      ).plan(query(network)).itineraries.first.estimatedFare,
      3.5,
    );
    final peak = RaptorPlanner(
      network,
    ).plan(query(network, end: 'B', departure: at(8))).itineraries.first;
    expect(peak.waitingMinutes, 3);
    expect(peak.vehicleMinutes, closeTo(3000 / (14000 / 60), .000001));
    expect(peak.durationMinutes, closeTo(4 + 3 + 3000 / (14000 / 60), .000001));
  });

  test('approved headways, boundaries and UTC clock conversion', () {
    final s = configured();
    for (final (hour, minute, headway) in <(int, int, double?)>[
      (5, 0, 10),
      (6, 59, 10),
      (7, 0, 6),
      (9, 0, 10),
      (12, 0, 10),
      (17, 0, 6),
      (20, 0, 15),
      (23, 0, null),
      (4, 59, null),
    ]) {
      expect(s.frequencyAt(at(hour, minute)), headway);
    }
    expect(s.speedAt(at(12)), 15);
    expect(PlannerSettings.cityClock(at(10)).hour, 10);
    expect(s.boardAt(at(22, 59)), isNull);
  });

  test(
    'travel integrates changing speed within a segment instead of freezing it',
    () {
      final s = configured();
      final end = s.travel(at(6, 58), 1000)!;
      final expected = 2 + (1000 - 2 * 22000 / 60) / (14000 / 60);
      expect(
        end.difference(at(6, 58)).inMicroseconds / 60000000,
        closeTo(expected, .000001),
      );
      expect(s.travel(at(22, 59), 10000), isNull);
    },
  );

  test(
    'earlier arrival can hold for a better headway instead of losing a connection',
    () {
      final stops = {
        'O': stop('O', 0),
        'X': stop('X', 4000),
        'Y': stop('Y', 5000),
      };
      final base = configured();
      final s = PlannerSettings(
        speeds: [
          const TimeBand(300, 1380, 60.0),
          const TimeBand(1380, 300, null),
        ],
        frequencies: base.frequencies,
      );
      final network = PlannerNetwork(
        stops: stops,
        patterns: [
          pattern('early', ['O', 'X'], [0, 4000], stops),
          pattern('later', ['O', 'X'], [0, 5000], stops),
          pattern('connection', ['X', 'Y'], [0, 1000], stops),
        ],
        transfers: {},
        settings: s,
      );
      final result = RaptorPlanner(network).plan(
        PlannerQuery(
          origin: point(0),
          destination: point(5000),
          departureAt: at(6, 50),
        ),
      );
      final best = result.itineraries.first;
      expect(best.arrivalAt, at(7, 4));
      expect(best.legs.whereType<TransitLeg>().map((leg) => leg.lineId), [
        'early',
        'connection',
      ]);
    },
  );

  test(
    'boarding times remain monotone across a headway drop; expected wait is separate',
    () {
      final settings = configured();
      final estimate = settings.boarding(at(6, 59))!;
      expect(estimate.at, at(7, 3));
      expect(estimate.expectedWaitMinutes, 3);
      DateTime? previous;
      for (var second = -180; second <= 180; second++) {
        final ready = at(7).add(Duration(seconds: second));
        final departure = settings.boardAt(ready)!;
        if (previous != null) expect(departure.isBefore(previous), isFalse);
        previous = departure;
      }
    },
  );

  test('loop visits preserve the correct order and clipped geometry', () {
    final stops = {
      'A': stop('A', 0),
      'M': stop('M', 1000),
      'B': stop('B', 3000),
    };
    final network = PlannerNetwork(
      stops: stops,
      patterns: [
        pattern('loop', ['A', 'M', 'A', 'B'], [0, 1000, 2000, 5000], stops),
      ],
      transfers: {},
      settings: configured(),
    );
    final best = RaptorPlanner(network)
        .plan(
          PlannerQuery(
            origin: point(1000),
            destination: point(3000),
            departureAt: at(10),
          ),
        )
        .itineraries
        .first;
    final ride = best.legs.whereType<TransitLeg>().single;
    expect(ride.boardingStop.id, 'M');
    expect(ride.intermediateStops.single.id, 'A');
    expect(ride.geometry.map((p) => p.longitude), [
      point(1000).longitude,
      0,
      point(3000).longitude,
    ]);
    expect(ride.vehicleMinutes, closeTo(4000 / 300, .000001));
  });

  test(
    'shape clipping interpolates original chainages without adding outside points',
    () {
      final shape = PlannerShape(
        points: [point(0), point(1000), point(3000)],
        distances: [0, 1000, 3000],
      );
      final clipped = shape.clip(500, 2000);
      expect(clipped.map((p) => p.longitude), [
        point(500).longitude,
        point(1000).longitude,
        point(2000).longitude,
      ]);
      expect(() => shape.clip(-1, 500), throwsArgumentError);
      expect(
        () => PlannerShape(points: [point(0), point(1)], distances: [0, 0]),
        throwsArgumentError,
      );
    },
  );

  test(
    'unknown points, invalid walking parameters and overlapping bands fail explicitly',
    () {
      expect(() => GeoPoint(double.nan, 0), throwsArgumentError);
      final base = configured();
      expect(
        () => PlannerSettings(
          speeds: base.speeds,
          frequencies: base.frequencies,
          walkMetersPerMinute: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => PlannerSettings(
          speeds: [const TimeBand(300, 1380, 22.0)],
          frequencies: base.frequencies,
        ),
        throwsArgumentError,
      );
      final config =
          jsonDecode(
                File(
                  'tool/build_city_pack/config/arequipa.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      config.remove('frequency_bands');
      expect(() => PlannerSettings.fromConfig(config), throwsArgumentError);
    },
  );

  test(
    'runs the same computation in an isolate with domain-only inputs',
    () async {
      final network = toy();
      final result = await planInIsolate(network, query(network));
      expect(result.itineraries.first.arrivalAt, at(10, 49));
      expect(result.itineraries.first.estimatedFare, 3);
    },
  );
}
