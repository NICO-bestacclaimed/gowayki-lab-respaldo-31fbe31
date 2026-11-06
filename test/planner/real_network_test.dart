import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'package:gowayki_lab/domain/planner/journey_planner.dart';
import 'package:gowayki_lab/domain/planner/planner_worker.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_installer.dart';
import 'package:gowayki_lab/infra/city_pack/planner_network_loader.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late PlannerWorker worker;
  late Map<String, GeoPoint> places;
  setUpAll(() async {
    support = await Directory.systemTemp.createTemp('gowayki-real-planner-');
    final installed = await CityPackInstaller(
      supportDirectory: () async => support,
    ).install();
    final network = await loadPlannerNetwork(installed);
    final db = sqlite3.open(installed.databasePath, mode: OpenMode.readOnly);
    places = {};
    try {
      for (final row in db.select(
        'SELECT place_id,latitude,longitude FROM places',
      )) {
        places[row['place_id'] as String] = GeoPoint(
          (row['latitude'] as num).toDouble(),
          (row['longitude'] as num).toDouble(),
        );
      }
    } finally {
      db.close();
    }
    worker = await PlannerWorker.start(network);
  });
  tearDownAll(() async {
    await worker.close();
    if (p.dirname(support.absolute.path) !=
            p.normalize(Directory.systemTemp.absolute.path) ||
        !p.basename(support.path).startsWith('gowayki-real-planner-')) {
      throw StateError('Unsafe test cleanup');
    }
    await support.delete(recursive: true);
  });
  final cases = <String, (String, String)>{
    'TECSUP Arequipa → Mall Aventura Porongoche': (
      'osm:way:409177970',
      'osm:way:437694283',
    ),
    'Plaza de Armas → Terminal Terrestre': (
      'osm:way:23811932',
      'osm:way:198666186',
    ),
    'Yanahuara → Cerro Colorado (municipalidad central)': (
      'osm:node:4262845116',
      'osm:node:4126637264',
    ),
  };
  for (final entry in cases.entries) {
    test(entry.key, () async {
      final (from, to) = entry.value;
      final request = JourneyRequest(
        origin: places[from]!,
        destination: places[to]!,
        time: JourneyTime.leaveAt(DateTime.utc(2026, 11, 6, 15)),
      );
      final timer = Stopwatch()..start();
      final response = await worker.plan(request);
      timer.stop();
      final evidence = {
        'case': entry.key,
        'origin_osm': from,
        'destination_osm': to,
        'host_jit_roundtrip_ms': timer.elapsedMicroseconds / 1000,
        'status': response.status.name,
        'routes': response.itineraries
            .map(
              (trip) => {
                'minutes': trip.durationMinutes,
                'walk_meters': trip.walkingMeters,
                'transfers': trip.transfers,
                'fare_pen': trip.estimatedFare,
                'lines': trip.legs
                    .whereType<TransitLeg>()
                    .map((leg) => leg.lineName)
                    .toList(),
              },
            )
            .toList(),
      };
      // ignore: avoid_print
      print(jsonEncode(evidence));
      expect(response.status, JourneyStatus.success);
      expect(
        response.itineraries.any(
          (trip) =>
              trip.boardings > 0 &&
              trip.durationMinutes >= 10 &&
              trip.durationMinutes <= 90,
        ),
        isTrue,
      );
      expect(response.itineraries.length, lessThanOrEqualTo(5));
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
