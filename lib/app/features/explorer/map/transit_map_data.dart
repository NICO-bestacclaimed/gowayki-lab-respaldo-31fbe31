import '../../../../core/models/transit_line.dart';
import '../../../../domain/models/city_pack_models.dart';
import '../../../../domain/planner/itinerary.dart';

class MapRouteSelection {
  const MapRouteSelection(this.line, this.direction);
  final TransitLine line;
  final TransitDirection direction;
}

class TransitMapData {
  TransitMapData({
    required List<TransitLine> lines,
    required List<CityMapStop> stops,
  }) : lines = List.unmodifiable(lines),
       stops = Map.unmodifiable({for (final stop in stops) stop.stop.id: stop}),
       routes = Map.unmodifiable({
         for (final line in lines)
           for (final direction in line.directions)
             direction.routeId: MapRouteSelection(line, direction),
       });
  final List<TransitLine> lines;
  final Map<String, CityMapStop> stops;
  final Map<String, MapRouteSelection> routes;
  static Map<String, dynamic> collection(
    Iterable<Map<String, dynamic>> features,
  ) => {
    'type': 'FeatureCollection',
    'features': features.toList(growable: false),
  };
  Map<String, dynamic> routeFeatures({
    required TransitDirectionKind direction,
    bool visible = true,
    String? lineId,
  }) => collection([
    for (final route in routes.values)
      if (visible &&
          route.direction.kind == direction &&
          (lineId == null || route.line.id == lineId))
        {
          'type': 'Feature',
          'id': route.direction.routeId,
          'properties': {
            'line_id': route.line.id,
            'color': route.line.color,
            'headsign': route.direction.headsign,
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': route.direction.geometry
                .map((p) => [p[1], p[0]])
                .toList(growable: false),
          },
        },
  ]);
  Map<String, dynamic> stopFeatures({
    String? lineId,
    TransitDirectionKind? direction,
  }) => collection([
    for (final entry in stops.values)
      if (lineId == null ||
          entry.services.any(
            (s) =>
                s.lineId == lineId &&
                (direction == null || s.direction == direction.name),
          ))
        {
          'type': 'Feature',
          'id': entry.stop.id,
          'properties': {
            'name': entry.stop.needsReview
                ? '~ ${entry.stop.name}'
                : entry.stop.name,
            'needs_review': entry.stop.needsReview,
            'source_kind': entry.stop.sourceKind,
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [entry.stop.longitude, entry.stop.latitude],
          },
        },
  ]);
  static Map<String, dynamic> endpointFeatures({
    GeoPoint? origin,
    GeoPoint? destination,
  }) => collection([
    if (origin != null)
      {
        'type': 'Feature',
        'id': 'origin',
        'properties': {'label': 'A', 'color': '#237B53'},
        'geometry': {
          'type': 'Point',
          'coordinates': [origin.longitude, origin.latitude],
        },
      },
    if (destination != null)
      {
        'type': 'Feature',
        'id': 'destination',
        'properties': {'label': 'B', 'color': '#C8490A'},
        'geometry': {
          'type': 'Point',
          'coordinates': [destination.longitude, destination.latitude],
        },
      },
  ]);
  static Map<String, dynamic> journeyFeatures(
    List<Itinerary> trips, {
    required bool walking,
    required int selected,
  }) => collection([
    for (final (index, trip) in trips.indexed)
      for (final (legIndex, leg) in trip.legs.indexed)
        if ((leg is WalkLeg) == walking)
          {
            'type': 'Feature',
            'id': '$index:$legIndex',
            'properties': {
              'color': leg is TransitLeg ? leg.color : '#7A7F86',
              'width': index == selected ? 5 : 2.5,
              'opacity': index == selected ? 1.0 : .4,
            },
            'geometry': {
              'type': 'LineString',
              'coordinates': leg.geometry
                  .map((p) => [p.longitude, p.latitude])
                  .toList(growable: false),
            },
          },
  ]);
}
