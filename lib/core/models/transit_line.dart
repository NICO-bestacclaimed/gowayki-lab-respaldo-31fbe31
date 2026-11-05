/// Sentido GTFS: ida / vuelta.
enum TransitDirectionKind { ida, vuelta }

/// Un sentido de una combi (trazo + destino).
class TransitDirection {
  const TransitDirection({
    required this.kind,
    required this.routeId,
    required this.headsign,
    required this.longName,
    required this.geometry,
  });

  final TransitDirectionKind kind;
  final String routeId;
  final String headsign;
  final String longName;

  /// Pares [lat, lon].
  final List<List<double>> geometry;
}

/// Combi agrupada (mismo nombre + color) con ida y/o vuelta.
class TransitLine {
  const TransitLine({
    required this.id,
    required this.shortName,
    required this.color,
    required this.directions,
  });

  final String id;
  final String shortName;
  final String color;
  final List<TransitDirection> directions;

  TransitDirection? get ida {
    for (final d in directions) {
      if (d.kind == TransitDirectionKind.ida) return d;
    }
    return null;
  }

  TransitDirection? get vuelta {
    for (final d in directions) {
      if (d.kind == TransitDirectionKind.vuelta) return d;
    }
    return null;
  }
}
