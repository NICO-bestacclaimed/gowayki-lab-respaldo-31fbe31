// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'package:gowayki_lab/domain/planner/journey_planner.dart';
import 'package:gowayki_lab/domain/planner/planner_worker.dart';
import 'package:gowayki_lab/domain/planner/raptor_planner.dart';
import 'package:gowayki_lab/infra/city_pack/sqlite_planner_network_reader.dart';
import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> args) async {
  String option(String name, String fallback) => args
      .firstWhere(
        (a) => a.startsWith('--$name='),
        orElse: () => '--$name=$fallback',
      )
      .split('=')
      .skip(1)
      .join('=');
  final iterations = int.parse(option('iterations', '5'));
  RangeError.checkValueInInterval(iterations, 1, 50, 'iterations');
  final pack = File(option('pack', 'assets/city/arequipa/pack.sqlite'));
  final manifest =
      jsonDecode(File('${pack.parent.path}/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  if ((await sha256.bind(pack.openRead()).first).toString() !=
      manifest['sha256']) {
    throw StateError('Pack hash mismatch');
  }
  final timer = Stopwatch()..start();
  final network = readPlannerNetwork(pack.path);
  final db = sqlite3.open(pack.path, mode: OpenMode.readOnly);
  final locations = <String, GeoPoint>{};
  try {
    for (final row in db.select(
      'SELECT place_id,latitude,longitude FROM places',
    )) {
      locations[row['place_id'] as String] = GeoPoint(
        (row['latitude'] as num).toDouble(),
        (row['longitude'] as num).toDouble(),
      );
    }
  } finally {
    db.close();
  }
  if (args.contains('--profile')) {
    for (final (from, to) in [
      ('osm:way:409177970', 'osm:way:437694283'),
      ('osm:way:23811932', 'osm:way:198666186'),
      ('osm:node:4262845116', 'osm:node:4126637264'),
    ]) {
      final diagnostics = <String, Object?>{};
      final result = RaptorPlanner(network, diagnostics: diagnostics).plan(
        PlannerQuery(
          origin: locations[from]!,
          destination: locations[to]!,
          departureAt: DateTime.utc(2026, 11, 6, 15),
        ),
      );
      print(
        jsonEncode({
          'case': from,
          'candidates': result.itineraries.length,
          'profile': diagnostics,
        }),
      );
    }
    return;
  }
  final worker = await PlannerWorker.start(network);
  final startup = timer.elapsedMicroseconds / 1000;
  final cases = <String, (String, String)>{
    'TECSUP → Mall Aventura': ('osm:way:409177970', 'osm:way:437694283'),
    'Plaza de Armas → Terminal': ('osm:way:23811932', 'osm:way:198666186'),
    'Yanahuara → Cerro Colorado': (
      'osm:node:4262845116',
      'osm:node:4126637264',
    ),
  };
  final records = <Map<String, Object?>>[];
  Future<JourneyResponse> measure(
    String name,
    GeoPoint origin,
    GeoPoint destination,
    JourneyTime time, {
    required bool warmup,
  }) async {
    timer.reset();
    timer.start();
    final response = await worker.plan(
      JourneyRequest(origin: origin, destination: destination, time: time),
    );
    timer.stop();
    if (!warmup) {
      records.add({
        'case': name,
        'mode': time.mode.name,
        'milliseconds': timer.elapsedMicroseconds / 1000,
        'status': response.status.name,
        'routes': response.itineraries
            .map(
              (trip) => {
                'minutes': trip.durationMinutes,
                'walking_meters': trip.walkingMeters,
                'transfers': trip.transfers,
                'lines': trip.legs
                    .whereType<TransitLeg>()
                    .map((leg) => leg.lineName)
                    .toList(),
              },
            )
            .toList(),
      });
    }
    return response;
  }

  try {
    for (final entry in cases.entries) {
      final (from, to) = entry.value;
      await measure(
        entry.key,
        locations[from]!,
        locations[to]!,
        JourneyTime.leaveAt(DateTime.utc(2026, 11, 6, 15)),
        warmup: true,
      );
      for (var i = 0; i < iterations; i++) {
        final result = await measure(
          entry.key,
          locations[from]!,
          locations[to]!,
          JourneyTime.leaveAt(DateTime.utc(2026, 11, 6, 15)),
          warmup: false,
        );
        if (!result.itineraries.any(
          (trip) => trip.durationMinutes >= 10 && trip.durationMinutes <= 90,
        )) {
          throw StateError('Real trip acceptance failed: ${entry.key}');
        }
      }
      final deadline = DateTime.utc(2026, 11, 6, 16);
      final response = await measure(
        entry.key,
        locations[from]!,
        locations[to]!,
        JourneyTime.arriveBy(deadline),
        warmup: false,
      );
      if (response.itineraries.isEmpty ||
          response.itineraries.any((trip) => trip.arrivalAt.isAfter(deadline))) {
        throw StateError('Arrive-by acceptance failed');
      }
    }
    final random = Random(42);
    final served = network.stopPatterns.keys.toList()..sort();
    for (var i = 0; i < 10; i++) {
      final a = network.stops[served[random.nextInt(served.length)]]!;
      final b = network.stops[served[random.nextInt(served.length)]]!;
      await measure(
        'seed42:$i:${a.id}→${b.id}',
        GeoPoint.stop(a),
        GeoPoint.stop(b),
        JourneyTime.leaveAt(DateTime.utc(2026, 11, 6, 15)),
        warmup: false,
      );
    }
  } finally {
    await worker.close();
  }
  Map<String, Object> summary(Iterable<Map<String, Object?>> input) {
    final values = input.map((r) => r['milliseconds'] as double).toList()
      ..sort();
    final middle = values.length ~/ 2;
    return {
      'samples': values.length,
      'median_ms': values.length.isOdd
          ? values[middle]
          : (values[middle - 1] + values[middle]) / 2,
      'worst_ms': values.last,
      'host_under_400_ms': values.last < 400,
    };
  }

  final report = {
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'platform': Platform.operatingSystem,
    'os': Platform.operatingSystemVersion,
    'processors': Platform.numberOfProcessors,
    'dart': Platform.version,
    'execution': 'native CLI; use dart build cli for AOT',
    'android_midrange_validated': false,
    'pack_version': manifest['version'],
    'pack_sha256': manifest['sha256'],
    'startup_ms': startup,
    'summary': summary(records),
    'depart_at': summary(records.where((r) => r['mode'] == 'leaveAt')),
    'arrive_by': summary(records.where((r) => r['mode'] == 'arriveBy')),
    'records': records,
  };
  final output = File(
    option('output', '../.tools/logs/parte2D-benchmark-aot.json'),
  );
  await output.parent.create(recursive: true);
  await output.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    flush: true,
  );
  print(
    jsonEncode({
      'summary': report['summary'],
      'depart_at': report['depart_at'],
      'arrive_by': report['arrive_by'],
      'startup_ms': startup,
      'android_midrange_validated': false,
      'report': output.absolute.path,
    }),
  );
}
