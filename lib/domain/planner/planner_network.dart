import '../models/city_pack_models.dart';
import 'itinerary.dart';
import 'service_schedule.dart';

class PatternVisit {
  const PatternVisit(this.stopId, this.distanceMeters);
  final String stopId;
  final double distanceMeters;
}

class PlannerShape {
  PlannerShape({
    required List<GeoPoint> points,
    required List<double> distances,
  }) : points = List.unmodifiable(points),
       distances = List.unmodifiable(distances) {
    if (points.length < 2 ||
        points.length != distances.length ||
        distances.first != 0) {
      throw ArgumentError('Shape inválido.');
    }
    for (var i = 0; i < distances.length; i++) {
      if (!distances[i].isFinite ||
          distances[i] < 0 ||
          (i > 0 && distances[i] <= distances[i - 1])) {
        throw ArgumentError('Distancias de shape inválidas.');
      }
    }
  }
  final List<GeoPoint> points;
  final List<double> distances;

  GeoPoint _pointAt(double distance) {
    if (distance <= 0) return points.first;
    if (distance >= distances.last) return points.last;
    var low = 0, high = distances.length - 1;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      if (distances[middle] <= distance) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final t = (distance - distances[low]) / (distances[high] - distances[low]);
    return GeoPoint(
      points[low].latitude + t * (points[high].latitude - points[low].latitude),
      points[low].longitude +
          t * (points[high].longitude - points[low].longitude),
    );
  }

  List<GeoPoint> clip(double start, double end) {
    if (start < 0 || end < start || end > distances.last + .00001) {
      throw ArgumentError('Recorte fuera del shape.');
    }
    return List.unmodifiable([
      _pointAt(start),
      for (var i = 1; i < points.length - 1; i++)
        if (distances[i] > start && distances[i] < end) points[i],
      _pointAt(end),
    ]);
  }
}

class PlannerPattern {
  PlannerPattern({
    required this.id,
    required this.lineId,
    required this.lineName,
    required this.color,
    required this.direction,
    required this.headsign,
    required List<PatternVisit> visits,
    required this.shape,
    required this.fare,
  }) : visits = List.unmodifiable(visits);
  final String id, lineId, lineName, color, direction, headsign;
  final List<PatternVisit> visits;
  final PlannerShape shape;
  final CityFare fare;
}

class PlannerNetwork {
  PlannerNetwork({
    required Map<String, CityStop> stops,
    required List<PlannerPattern> patterns,
    required Map<String, List<CityTransfer>> transfers,
    required this.settings,
  }) : stops = Map.unmodifiable(stops),
       patterns = List.unmodifiable(patterns),
       transfers = Map.unmodifiable(
         transfers.map(
           (id, edges) => MapEntry(id, List<CityTransfer>.unmodifiable(edges)),
         ),
       ) {
    final occurrences = <String, List<(int, int)>>{};
    final ids = <String>{};
    for (var p = 0; p < patterns.length; p++) {
      final pattern = patterns[p];
      if (!ids.add(pattern.id) ||
          pattern.visits.length < 2 ||
          !pattern.fare.amount.isFinite ||
          pattern.fare.amount < 0 ||
          pattern.fare.currency != 'PEN') {
        throw ArgumentError('Patrón/tarifa inválidos.');
      }
      for (var i = 0; i < pattern.visits.length; i++) {
        final visit = pattern.visits[i];
        if (!stops.containsKey(visit.stopId) ||
            !visit.distanceMeters.isFinite ||
            visit.distanceMeters < 0 ||
            visit.distanceMeters > pattern.shape.distances.last + .00001 ||
            (i > 0 &&
                visit.distanceMeters < pattern.visits[i - 1].distanceMeters)) {
          throw ArgumentError('Visita inválida.');
        }
        (occurrences[visit.stopId] ??= []).add((p, i));
      }
    }
    final incoming = <String, List<(String, double)>>{};
    for (final entry in transfers.entries) {
      if (!stops.containsKey(entry.key)) {
        throw ArgumentError('Origen de transbordo desconocido.');
      }
      for (final edge in entry.value) {
        (incoming[edge.toStopId] ??= []).add((entry.key, edge.walkMeters));
        if (!stops.containsKey(edge.toStopId) ||
            !edge.walkMeters.isFinite ||
            !edge.directMeters.isFinite ||
            edge.walkMeters < edge.directMeters ||
            edge.directMeters < 0 ||
            edge.directMeters > 400.000002 ||
            edge.walkMeters > 520.000002) {
          throw ArgumentError('Transbordo inválido.');
        }
      }
    }
    incomingTransfers = Map.unmodifiable(
      incoming.map(
        (id, edges) => MapEntry(id, List<(String, double)>.unmodifiable(edges)),
      ),
    );
    stopPatterns = Map.unmodifiable(
      occurrences.map(
        (id, visits) => MapEntry(id, List<(int, int)>.unmodifiable(visits)),
      ),
    );
  }
  final Map<String, CityStop> stops;
  final List<PlannerPattern> patterns;
  final Map<String, List<CityTransfer>> transfers;
  final PlannerSettings settings;
  late final Map<String, List<(int, int)>> stopPatterns;
  late final Map<String, List<(String, double)>> incomingTransfers;
}
