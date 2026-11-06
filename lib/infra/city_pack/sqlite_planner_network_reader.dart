import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';
import '../../domain/models/city_pack_models.dart';
import '../../domain/planner/itinerary.dart';
import '../../domain/planner/planner_network.dart';
import '../../domain/planner/service_schedule.dart';

PlannerNetwork readPlannerNetwork(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final config = <String, Object?>{
      for (final row in db.select(
        'SELECT key,value_json FROM config WHERE city_code=?',
        ['arequipa'],
      ))
        row['key'] as String: jsonDecode(row['value_json'] as String),
    };
    final settings = PlannerSettings.fromConfig(config);
    final defaultFare = config['default_fare'] as Map<String, dynamic>;
    final stops = <String, CityStop>{};
    for (final row in db.select('SELECT * FROM stops')) {
      final stop = CityStop(
        id: row['stop_id'] as String,
        name: row['name'] as String,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        sourceKind: row['source_kind'] as String,
        nameSource: row['name_source'] as String,
        needsReview: row['needs_review'] == 1,
        usedInPatterns: row['used_in_patterns'] == 1,
      );
      stops[stop.id] = stop;
    }
    final shapes = <String, PlannerShape>{};
    for (final row in db.select(
      'SELECT shape_id,geometry_json,vertex_distances_json FROM shapes',
    )) {
      final geometry =
          jsonDecode(row['geometry_json'] as String) as Map<String, dynamic>;
      shapes[row['shape_id'] as String] = PlannerShape(
        points: (geometry['coordinates'] as List<dynamic>)
            .map(
              (dynamic p) =>
                  GeoPoint((p[1] as num).toDouble(), (p[0] as num).toDouble()),
            )
            .toList(),
        distances:
            (jsonDecode(row['vertex_distances_json'] as String)
                    as List<dynamic>)
                .map((dynamic value) => (value as num).toDouble())
                .toList(),
      );
    }
    final visits = <String, List<PatternVisit>>{};
    for (final row in db.select(
      'SELECT pattern_id,stop_id,distance_m FROM pattern_stops ORDER BY pattern_id,stop_sequence',
    )) {
      (visits[row['pattern_id'] as String] ??= []).add(
        PatternVisit(
          row['stop_id'] as String,
          (row['distance_m'] as num).toDouble(),
        ),
      );
    }
    final patterns = <PlannerPattern>[];
    for (final row in db.select('''
      SELECT p.*,l.name,l.color,f.amount FROM patterns p
      JOIN lines l ON l.line_id=p.line_id LEFT JOIN line_fares f ON f.line_id=p.line_id
      ORDER BY p.pattern_id
    ''')) {
      patterns.add(
        PlannerPattern(
          id: row['pattern_id'] as String,
          lineId: row['line_id'] as String,
          lineName: row['name'] as String,
          color: row['color'] as String,
          direction: row['direction'] as String,
          headsign: row['headsign'] as String,
          visits: visits[row['pattern_id']]!,
          shape: shapes[row['shape_id']]!,
          fare: CityFare(
            amount: ((row['amount'] ?? defaultFare['amount']) as num)
                .toDouble(),
            currency: defaultFare['currency'] as String,
          ),
        ),
      );
    }
    final transfers = <String, List<CityTransfer>>{};
    for (final row in db.select('SELECT * FROM transfers')) {
      final a = row['stop_a'] as String, b = row['stop_b'] as String;
      final direct = (row['direct_distance_m'] as num).toDouble();
      final walk = (row['walk_distance_m'] as num).toDouble();
      (transfers[a] ??= []).add(
        CityTransfer(toStopId: b, directMeters: direct, walkMeters: walk),
      );
      (transfers[b] ??= []).add(
        CityTransfer(toStopId: a, directMeters: direct, walkMeters: walk),
      );
    }
    return PlannerNetwork(
      stops: stops,
      patterns: patterns,
      transfers: transfers,
      settings: settings,
    );
  } finally {
    db.close();
  }
}
