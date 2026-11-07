import '../../../../domain/models/city_pack_models.dart';
import '../../../../domain/planner/itinerary.dart';

class NearbyStop {
  const NearbyStop(this.entry, this.walkMeters);
  final CityMapStop entry;
  final double walkMeters;
}

List<NearbyStop> nearbyStops(
  Iterable<CityMapStop> stops,
  GeoPoint point, {
  double limitMeters = 1500,
  int limit = 30,
}) {
  final found = <NearbyStop>[];
  for (final stop in stops) {
    final distance =
        point.distanceTo(GeoPoint(stop.stop.latitude, stop.stop.longitude)) *
        1.3;
    if (distance <= limitMeters) found.add(NearbyStop(stop, distance));
  }
  found.sort((a, b) {
    final distance = a.walkMeters.compareTo(b.walkMeters);
    return distance == 0
        ? a.entry.stop.id.compareTo(b.entry.stop.id)
        : distance;
  });
  return List.unmodifiable(found.take(limit));
}
