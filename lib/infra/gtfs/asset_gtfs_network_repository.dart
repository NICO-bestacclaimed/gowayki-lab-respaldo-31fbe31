import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '../../core/models/transit_line.dart';
import '../../domain/repositories/transit_network_repository.dart';

/// Carga `assets/gtfs/network.json` (combis con ida/vuelta).
class AssetGtfsNetworkRepository implements TransitNetworkRepository {
  AssetGtfsNetworkRepository({this.assetPath = 'assets/gtfs/network.json'});

  final String assetPath;
  Future<List<TransitLine>>? _cache;

  @override
  Future<List<TransitLine>> lines() => _cache ??= _load();

  Future<List<TransitLine>> _load() async {
    final raw = await rootBundle.loadString(assetPath);
    return Isolate.run(() {
      final list =
          (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      return list.map(_parseLine).toList(growable: false);
    });
  }

  static TransitLine _parseLine(Map<String, dynamic> m) {
    final dirs = (m['directions'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_parseDirection)
        .toList(growable: false);
    return TransitLine(
      id: m['id'] as String? ?? '',
      shortName: m['short_name'] as String? ?? '',
      color: m['color'] as String? ?? '#F05709',
      directions: dirs,
    );
  }

  static TransitDirection _parseDirection(Map<String, dynamic> m) {
    final kind = (m['kind'] as String?) == 'vuelta'
        ? TransitDirectionKind.vuelta
        : TransitDirectionKind.ida;
    return TransitDirection(
      kind: kind,
      routeId: m['route_id'] as String? ?? '',
      headsign: m['headsign'] as String? ?? '',
      longName: m['long_name'] as String? ?? '',
      geometry: (m['geometry'] as List<dynamic>)
          .map(
            (p) => (p as List<dynamic>)
                .map((n) => (n as num).toDouble())
                .toList(growable: false),
          )
          .toList(growable: false),
    );
  }
}
