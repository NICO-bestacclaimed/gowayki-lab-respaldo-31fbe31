/// A source candidate or generated point; never a certified physical stop.
class CityStop {
  const CityStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.sourceKind,
    required this.nameSource,
    required this.needsReview,
    required this.usedInPatterns,
  });
  final String id, name, sourceKind, nameSource;
  final double latitude, longitude;
  final bool needsReview, usedInPatterns;
  bool get isVirtual => sourceKind == 'generated_virtual';
}

class CityPattern {
  const CityPattern({
    required this.id,
    required this.lineId,
    required this.routeId,
    required this.shapeId,
    required this.direction,
    required this.headsign,
    required this.lengthMeters,
  });
  final String id, lineId, routeId, shapeId, direction, headsign;
  final double lengthMeters;
}

class CityPatternStop {
  const CityPatternStop({
    required this.stop,
    required this.sequence,
    required this.distanceMeters,
    required this.offsetMeters,
    required this.shapeLatitude,
    required this.shapeLongitude,
  });
  final CityStop stop;
  final int sequence;

  /// Chainage on the original shape, also used by CityShape.vertexDistances.
  final double distanceMeters, offsetMeters, shapeLatitude, shapeLongitude;
}

class CityPlace {
  const CityPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.coordinateSource,
  });
  final String id, name, category, address, coordinateSource;

  /// May be the center of an OSM feature's bounding box, not an entrance.
  final double latitude, longitude;
}

class CityTransfer {
  const CityTransfer({
    required this.toStopId,
    required this.directMeters,
    required this.walkMeters,
  });
  final String toStopId;
  final double directMeters, walkMeters;
}

class CityShape {
  const CityShape({
    required this.id,
    required this.coordinates,
    required this.vertexDistances,
  });
  final String id;

  /// GeoJSON pairs [longitude, latitude].
  final List<List<double>> coordinates;

  /// Original chainage at each retained vertex, in meters.
  final List<double> vertexDistances;
}

class CityFare {
  const CityFare({required this.amount, required this.currency});
  final double amount;
  final String currency;
}
