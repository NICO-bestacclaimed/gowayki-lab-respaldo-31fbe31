import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:gowayki_lab/domain/models/city_pack_models.dart';
import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'package:gowayki_lab/domain/planner/planner_network.dart';
import 'package:gowayki_lab/domain/planner/raptor_planner.dart';
import 'package:gowayki_lab/domain/planner/service_schedule.dart';

const metersPerDegree = 6371008.8 * math.pi / 180;
GeoPoint point(double meters) => GeoPoint(0, meters / metersPerDegree);
DateTime at(int hour, [int minute = 0, int second = 0]) =>
    DateTime.utc(2026, 11, 6, hour + 5, minute, second);
CityStop stop(String id, double meters) => CityStop(
  id: id,
  name: 'Prueba $id',
  latitude: 0,
  longitude: meters / metersPerDegree,
  sourceKind: 'gtfs_candidate',
  nameSource: 'gtfs_source',
  needsReview: false,
  usedInPatterns: true,
);
PlannerSettings configured() => PlannerSettings.fromConfig(
  (jsonDecode(
        File('tool/build_city_pack/config/arequipa.json').readAsStringSync(),
      )
      as Map<String, dynamic>),
);

PlannerPattern pattern(
  String id,
  List<String> stops,
  List<double> distances,
  Map<String, CityStop> all, {
  double fare = 1,
}) => PlannerPattern(
  id: id,
  lineId: id,
  lineName: 'Línea de prueba $id',
  color: '#123456',
  direction: 'ida',
  headsign: stops.last,
  visits: [
    for (var i = 0; i < stops.length; i++) PatternVisit(stops[i], distances[i]),
  ],
  shape: PlannerShape(
    points: [for (final id in stops) GeoPoint.stop(all[id]!)],
    distances: distances,
  ),
  fare: CityFare(amount: fare, currency: 'PEN'),
);

PlannerNetwork toy({double secondFare = 1, bool fourth = false}) {
  final locations = <String, double>{
    'A': 0,
    'M': 1500,
    'B': 3000,
    'C': 3000 + 150 / 1.3,
    'D': 4800 + 150 / 1.3,
    'E': 4800 + 300 / 1.3,
    'F': 7800 + 300 / 1.3,
    if (fourth) 'G': 10800 + 300 / 1.3,
  };
  final stops = locations.map((id, meters) => MapEntry(id, stop(id, meters)));
  CityTransfer edge(String id) =>
      CityTransfer(toStopId: id, directMeters: 150 / 1.3, walkMeters: 150);
  return PlannerNetwork(
    stops: stops,
    patterns: [
      pattern('R1', ['A', 'M', 'B'], [0, 1500, 3000], stops),
      pattern('R2', ['C', 'D'], [0, 1800], stops, fare: secondFare),
      pattern('R3', ['E', 'F'], [0, 3000], stops),
      if (fourth) pattern('R4', ['F', 'G'], [0, 3000], stops),
    ],
    transfers: {
      'B': [edge('C')],
      'C': [edge('B')],
      'D': [edge('E')],
      'E': [edge('D')],
    },
    settings: configured(),
  );
}

PlannerQuery query(
  PlannerNetwork network, {
  String end = 'F',
  double entry = 150,
  double exit = 150,
  DateTime? departure,
  int maxBoardings = 3,
}) => PlannerQuery(
  origin: GeoPoint(-entry / 1.3 / metersPerDegree, 0),
  destination: GeoPoint(
    exit / 1.3 / metersPerDegree,
    network.stops[end]!.longitude,
  ),
  departureAt: departure ?? at(10),
  maxBoardings: maxBoardings,
);
