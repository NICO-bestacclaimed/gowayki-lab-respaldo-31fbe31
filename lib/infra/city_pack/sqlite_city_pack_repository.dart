import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../core/models/transit_line.dart';
import '../../domain/models/city_pack_models.dart';
import '../../domain/repositories/city_pack_repository.dart';
import 'city_pack_installer.dart';
import 'city_pack_manifest.dart';

/// Read-only queries over a verified, private copy of the bundled city pack.
class SqliteCityPackRepository implements CityPackRepository {
  SqliteCityPackRepository._(this.installed, this._db);
  final InstalledCityPack installed;
  final Database _db;
  bool _closed = false;
  List<TransitLine>? _lines;

  static Future<SqliteCityPackRepository> open({
    CityPackInstaller? installer,
  }) async {
    final installed = await (installer ?? CityPackInstaller()).install();
    final db = sqlite3.open(installed.databasePath, mode: OpenMode.readOnly);
    return SqliteCityPackRepository._(installed, db);
  }

  @override
  Future<CityPackInfo> packageInfo() async {
    _ensureOpen();
    return CityPackInfo(
      cityCode: 'arequipa',
      version: manifest.version,
      generatedAt: manifest.generatedAt,
      sha256: manifest.sha256,
    );
  }

  CityPackManifest get manifest => installed.manifest;
  CityPackVersionStatus compareVersion(CityPackManifest candidate) =>
      manifest.compare(candidate);

  void _ensureOpen() {
    if (_closed) throw StateError('El repositorio del paquete está cerrado.');
  }

  @override
  Future<List<TransitLine>> lines() async {
    _ensureOpen();
    if (_lines case final cached?) return cached;
    final directions = <String, List<TransitDirection>>{};
    final rows = _db.select('''
      SELECT p.line_id,p.direction,p.route_id,p.headsign,r.long_name,s.geometry_json
      FROM patterns p JOIN routes r USING(route_id) JOIN shapes s ON s.shape_id=p.shape_id
      ORDER BY p.line_id,CASE p.direction WHEN 'ida' THEN 0 ELSE 1 END,p.pattern_id
    ''');
    for (final row in rows) {
      final geometry =
          jsonDecode(row['geometry_json'] as String) as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      (directions[row['line_id'] as String] ??= []).add(
        TransitDirection(
          kind: row['direction'] == 'ida'
              ? TransitDirectionKind.ida
              : TransitDirectionKind.vuelta,
          routeId: row['route_id'] as String,
          headsign: row['headsign'] as String,
          longName: row['long_name'] as String,
          // The existing map consumes [lat, lon]; SQLite geometry is GeoJSON [lon, lat].
          geometry: List.unmodifiable(
            coordinates.map((dynamic point) {
              final pair = point as List<dynamic>;
              return List<double>.unmodifiable([
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              ]);
            }),
          ),
        ),
      );
    }
    return _lines = List.unmodifiable(
      _db
          .select('SELECT * FROM lines ORDER BY line_id')
          .map(
            (row) => TransitLine(
              id: row['line_id'] as String,
              shortName: row['name'] as String,
              color: row['color'] as String,
              directions: List.unmodifiable(
                directions[row['line_id']] ?? const <TransitDirection>[],
              ),
            ),
          ),
    );
  }

  static CityStop _stop(Map<String, dynamic> row) => CityStop(
    id: row['stop_id'] as String,
    name: row['name'] as String,
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    sourceKind: row['source_kind'] as String,
    nameSource: row['name_source'] as String,
    needsReview: row['needs_review'] == 1,
    usedInPatterns: row['used_in_patterns'] == 1,
  );

  @override
  Future<List<CityStop>> stops({int limit = 100, int offset = 0}) async {
    _ensureOpen();
    RangeError.checkValueInInterval(limit, 1, 1000, 'limit');
    RangeError.checkNotNegative(offset, 'offset');
    return List.unmodifiable(
      _db
          .select('SELECT * FROM stops ORDER BY stop_id LIMIT ? OFFSET ?', [
            limit,
            offset,
          ])
          .map(_stop),
    );
  }

  @override
  Future<CityStop?> stop(String id) async {
    _ensureOpen();
    final rows = _db.select('SELECT * FROM stops WHERE stop_id=?', [id]);
    return rows.isEmpty ? null : _stop(rows.single);
  }

  @override
  Future<List<CityPattern>> patternsForLine(String lineId) async {
    _ensureOpen();
    return List.unmodifiable(
      _db
          .select(
            '''
      SELECT * FROM patterns WHERE line_id=?
      ORDER BY CASE direction WHEN 'ida' THEN 0 ELSE 1 END,pattern_id
    ''',
            [lineId],
          )
          .map(
            (row) => CityPattern(
              id: row['pattern_id'] as String,
              lineId: row['line_id'] as String,
              routeId: row['route_id'] as String,
              shapeId: row['shape_id'] as String,
              direction: row['direction'] as String,
              headsign: row['headsign'] as String,
              lengthMeters: (row['length_m'] as num).toDouble(),
            ),
          ),
    );
  }

  @override
  Future<List<CityPatternStop>> patternStops(String patternId) async {
    _ensureOpen();
    return List.unmodifiable(
      _db
          .select(
            '''
      SELECT s.*,ps.stop_sequence,ps.distance_m,ps.offset_m,ps.shape_latitude,ps.shape_longitude
      FROM pattern_stops ps JOIN stops s USING(stop_id)
      WHERE ps.pattern_id=? ORDER BY ps.stop_sequence
    ''',
            [patternId],
          )
          .map(
            (row) => CityPatternStop(
              stop: _stop(row),
              sequence: row['stop_sequence'] as int,
              distanceMeters: (row['distance_m'] as num).toDouble(),
              offsetMeters: (row['offset_m'] as num).toDouble(),
              shapeLatitude: (row['shape_latitude'] as num).toDouble(),
              shapeLongitude: (row['shape_longitude'] as num).toDouble(),
            ),
          ),
    );
  }

  @override
  Future<CityShape?> shape(String shapeId) async {
    _ensureOpen();
    final rows = _db.select('SELECT * FROM shapes WHERE shape_id=?', [shapeId]);
    if (rows.isEmpty) return null;
    final row = rows.single;
    final geometry =
        jsonDecode(row['geometry_json'] as String) as Map<String, dynamic>;
    return CityShape(
      id: shapeId,
      coordinates: List.unmodifiable(
        (geometry['coordinates'] as List<dynamic>).map(
          (dynamic point) => List<double>.unmodifiable(
            (point as List<dynamic>).map(
              (dynamic value) => (value as num).toDouble(),
            ),
          ),
        ),
      ),
      vertexDistances: List<double>.unmodifiable(
        (jsonDecode(row['vertex_distances_json'] as String) as List<dynamic>)
            .map((dynamic value) => (value as num).toDouble()),
      ),
    );
  }

  @override
  Future<List<CityTransfer>> transfersFrom(String stopId) async {
    _ensureOpen();
    return List.unmodifiable(
      _db
          .select(
            '''
      SELECT to_stop_id,direct_distance_m,walk_distance_m FROM transfer_edges
      WHERE from_stop_id=? ORDER BY walk_distance_m,to_stop_id
    ''',
            [stopId],
          )
          .map(
            (row) => CityTransfer(
              toStopId: row['to_stop_id'] as String,
              directMeters: (row['direct_distance_m'] as num).toDouble(),
              walkMeters: (row['walk_distance_m'] as num).toDouble(),
            ),
          ),
    );
  }

  @override
  Future<List<CityPlace>> searchPlaces(String query, {int limit = 20}) async {
    _ensureOpen();
    RangeError.checkValueInInterval(limit, 1, 100, 'limit');
    if (query.length > 512) {
      throw ArgumentError.value(
        query.length,
        'query',
        'Máximo 512 caracteres.',
      );
    }
    // Quote Unicode prefix tokens; caller-supplied FTS syntax is never executed.
    final tokens = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(query).take(12);
    final expression = tokens.map((match) => '"${match[0]}"*').join(' AND ');
    if (expression.isEmpty) return const [];
    return List.unmodifiable(
      _db
          .select(
            '''
      SELECT p.* FROM places_fts JOIN places p ON p.id=places_fts.rowid
      WHERE places_fts MATCH ? ORDER BY bm25(places_fts),p.place_id LIMIT ?
    ''',
            [expression, limit],
          )
          .map(
            (row) => CityPlace(
              id: row['place_id'] as String,
              name: row['name'] as String,
              category: row['category'] as String,
              latitude: (row['latitude'] as num).toDouble(),
              longitude: (row['longitude'] as num).toDouble(),
              address: row['address'] as String,
              coordinateSource: row['coordinate_source'] as String,
            ),
          ),
    );
  }

  @override
  Future<Map<String, Object?>> configuration() async {
    _ensureOpen();
    return Map.unmodifiable({
      for (final row in _db.select(
        'SELECT key,value_json FROM config WHERE city_code=? ORDER BY key',
        ['arequipa'],
      ))
        row['key'] as String: jsonDecode(row['value_json'] as String),
    });
  }

  @override
  Future<CityFare?> fareForLine(String lineId) async {
    _ensureOpen();
    if (_db.select('SELECT 1 FROM lines WHERE line_id=?', [lineId]).isEmpty) {
      return null;
    }
    final rows = _db.select(
      'SELECT amount,currency FROM line_fares WHERE line_id=?',
      [lineId],
    );
    if (rows.isNotEmpty) {
      return CityFare(
        amount: (rows.single['amount'] as num).toDouble(),
        currency: rows.single['currency'] as String,
      );
    }
    final config = await configuration();
    final fare = config['default_fare'] as Map<String, dynamic>;
    return CityFare(
      amount: (fare['amount'] as num).toDouble(),
      currency: fare['currency'] as String,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _lines = null;
    _db.close();
  }
}
