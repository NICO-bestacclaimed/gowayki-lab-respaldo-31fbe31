import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/domain/models/city_pack_models.dart';
import 'package:gowayki_lab/domain/planner/itinerary_selection.dart';
import 'package:gowayki_lab/domain/planner/planner_network.dart';
import 'package:gowayki_lab/domain/planner/raptor_planner.dart';
import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'toy_network.dart';

void main() {
  test(
    'destination bounds preserve the unpruned Pareto scores on seeded networks',
    () {
      final random = Random(23);
      for (var sample = 0; sample < 20; sample++) {
        final stops = {for (var i = 0; i < 8; i++) 's$i': stop('s$i', i * 300)};
        final patterns = <PlannerPattern>[];
        for (var route = 0; route < 6; route++) {
          final ids = <String>['s0'];
          final distances = <double>[0];
          var index = 0;
          var cumulative = 0.0;
          while (index < 7) {
            final next = min(7, index + 1 + random.nextInt(3));
            cumulative += (next - index) * 300 * (1 + random.nextInt(4) * .15);
            index = next;
            ids.add('s$index');
            distances.add(cumulative);
          }
          patterns.add(pattern('r$route', ids, distances, stops));
        }
        final transfers = <String, List<CityTransfer>>{};
        for (var i = 0; i < 7; i++) {
          (transfers['s$i'] ??= []).add(
            CityTransfer(
              toStopId: 's${i + 1}',
              directMeters: 300,
              walkMeters: 390,
            ),
          );
          (transfers['s${i + 1}'] ??= []).add(
            CityTransfer(toStopId: 's$i', directMeters: 300, walkMeters: 390),
          );
        }
        final network = PlannerNetwork(
          stops: stops,
          patterns: patterns,
          transfers: transfers,
          settings: configured(),
        );
        final q = PlannerQuery(
          origin: GeoPoint(-10 / 1.3 / metersPerDegree, 0),
          destination: GeoPoint(
            40 / 1.3 / metersPerDegree,
            point(2100).longitude,
          ),
          departureAt: sample.isEven ? at(10) : at(6, 58),
        );
        final reference = RaptorPlanner(
          network,
          useDestinationBounds: false,
        ).plan(q);
        final bounded = RaptorPlanner(network).plan(q);
        for (final order in JourneyOrder.values) {
          List<Object> scores(Iterable<Itinerary> choices) =>
              selectItineraries(choices, order)
                  .map(
                    (trip) => <Object>[
                      trip.durationMinutes,
                      trip.walkingMeters,
                      trip.transfers,
                    ],
                  )
                  .toList();
          expect(
            scores(bounded.itineraries),
            scores(reference.itineraries),
            reason: 'seed23 sample $sample / $order',
          );
        }
      }
    },
  );

  test(
    'retains five distinct combinations when more have identical metrics',
    () {
      final stops = {'A': stop('A', 0), 'B': stop('B', 3000)};
      final network = PlannerNetwork(
        stops: stops,
        patterns: [
          for (var i = 0; i < 7; i++)
            pattern('equal$i', ['A', 'B'], [0, 3000], stops),
        ],
        transfers: {},
        settings: configured(),
      );
      final result = RaptorPlanner(network).plan(
        PlannerQuery(
          origin: point(0),
          destination: point(3000),
          departureAt: at(10),
        ),
      );
      final selected = selectItineraries(
        result.itineraries,
        JourneyOrder.fastest,
      );
      expect(selected, hasLength(5));
      expect(selected.map(lineCombination).toSet(), hasLength(5));
      expect(
        selected.every(
          (trip) => trip.durationMinutes == 15 && trip.walkingMeters == 0,
        ),
        isTrue,
      );
    },
  );

  test('inverse waiting stays strictly before the 23:00 boarding closure', () {
    final ready = configured().readyBefore(at(23), at(5))!;
    expect(ready, at(22, 52, 30).subtract(const Duration(microseconds: 1)));
    expect(configured().boardAt(ready)!.isBefore(at(23)), isTrue);
  });
}
