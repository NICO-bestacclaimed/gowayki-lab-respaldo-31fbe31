import 'package:sqlite3/sqlite3.dart';
import '../../domain/models/city_pack_models.dart';

/// New read-only connection owned by the loading isolate.
List<CityMapStop> readMapStops(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final services = <String, List<CityStopService>>{};
    for (final row in db.select(
      '''SELECT DISTINCT ps.stop_id,p.line_id,p.pattern_id,p.route_id,p.direction,p.headsign
      FROM pattern_stops ps JOIN patterns p USING(pattern_id) ORDER BY ps.stop_id,p.line_id,p.pattern_id''',
    )) {
      (services[row['stop_id'] as String] ??= []).add(
        CityStopService(
          lineId: row['line_id'] as String,
          patternId: row['pattern_id'] as String,
          routeId: row['route_id'] as String,
          direction: row['direction'] as String,
          headsign: row['headsign'] as String,
        ),
      );
    }
    return List.unmodifiable(
      db
          .select(
            'SELECT * FROM stops WHERE used_in_patterns=1 ORDER BY stop_id',
          )
          .map(
            (row) => CityMapStop(
              stop: CityStop(
                id: row['stop_id'] as String,
                name: row['name'] as String,
                latitude: (row['latitude'] as num).toDouble(),
                longitude: (row['longitude'] as num).toDouble(),
                sourceKind: row['source_kind'] as String,
                nameSource: row['name_source'] as String,
                needsReview: row['needs_review'] == 1,
                usedInPatterns: row['used_in_patterns'] == 1,
              ),
              services: services[row['stop_id']] ?? const [],
            ),
          ),
    );
  } finally {
    db.close();
  }
}
