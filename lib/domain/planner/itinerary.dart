import 'dart:math' as math;

import '../models/city_pack_models.dart';

class GeoPoint {
  GeoPoint(this.latitude, this.longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw ArgumentError('Coordenada inválida.');
    }
  }
  final double latitude, longitude;
  double distanceTo(GeoPoint other) {
    const radians = math.pi / 180;
    final a =
        math.pow(math.sin((other.latitude - latitude) * radians / 2), 2) +
        math.cos(latitude * radians) *
            math.cos(other.latitude * radians) *
            math.pow(math.sin((other.longitude - longitude) * radians / 2), 2);
    return 6371008.8 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }

  static GeoPoint stop(CityStop stop) =>
      GeoPoint(stop.latitude, stop.longitude);
}

sealed class JourneyLeg {
  JourneyLeg({required this.departureAt, required this.arrivalAt});
  final DateTime departureAt, arrivalAt;
  GeoPoint get from;
  GeoPoint get to;
  List<GeoPoint> get geometry;
  double get durationMinutes =>
      arrivalAt.difference(departureAt).inMicroseconds / 60000000;
}

class WalkLeg extends JourneyLeg {
  WalkLeg({
    required this.from,
    required this.to,
    required this.meters,
    required super.departureAt,
    required super.arrivalAt,
  }) : geometry = List.unmodifiable([from, to]);
  @override
  final GeoPoint from, to;
  final double meters;

  /// Estimated straight-line geometry, not a validated pedestrian path.
  @override
  final List<GeoPoint> geometry;
}

class TransitLeg extends JourneyLeg {
  TransitLeg({
    required this.lineId,
    required this.lineName,
    required this.color,
    required this.patternId,
    required this.direction,
    required this.headsign,
    required this.boardingStop,
    required this.alightingStop,
    required List<CityStop> intermediateStops,
    required this.boardingAt,
    required this.expectedWaitMinutes,
    required this.fare,
    required List<GeoPoint> geometry,
    required super.departureAt,
    required super.arrivalAt,
  }) : intermediateStops = List.unmodifiable(intermediateStops),
       geometry = List.unmodifiable(geometry);
  final String lineId, lineName, color, patternId, direction, headsign;
  final CityStop boardingStop, alightingStop;
  final List<CityStop> intermediateStops;
  final DateTime boardingAt;
  final double expectedWaitMinutes;
  double get waitingForBandMinutes =>
      math.max(0, waitMinutes - expectedWaitMinutes);
  final CityFare fare;

  /// Stops passed after boarding, including the alighting stop.
  int get stopCount => intermediateStops.length + 1;
  double get waitMinutes =>
      boardingAt.difference(departureAt).inMicroseconds / 60000000;
  double get vehicleMinutes =>
      arrivalAt.difference(boardingAt).inMicroseconds / 60000000;
  @override
  GeoPoint get from => GeoPoint.stop(boardingStop);
  @override
  GeoPoint get to => GeoPoint.stop(alightingStop);
  @override
  final List<GeoPoint> geometry;
}

class Itinerary {
  Itinerary({
    required this.departureAt,
    required this.arrivalAt,
    required List<JourneyLeg> legs,
  }) : legs = List.unmodifiable(legs);

  /// Absolute instants in UTC. The city clock is America/Lima (UTC-05).
  final DateTime departureAt, arrivalAt;
  final List<JourneyLeg> legs;
  double get durationMinutes =>
      arrivalAt.difference(departureAt).inMicroseconds / 60000000;
  double get walkingMinutes => legs.whereType<WalkLeg>().fold(
    0,
    (sum, leg) => sum + leg.durationMinutes,
  );
  double get walkingMeters =>
      legs.whereType<WalkLeg>().fold(0, (sum, leg) => sum + leg.meters);
  double get waitingMinutes =>
      legs.whereType<TransitLeg>().fold(0, (sum, leg) => sum + leg.waitMinutes);
  double get vehicleMinutes => legs.whereType<TransitLeg>().fold(
    0,
    (sum, leg) => sum + leg.vehicleMinutes,
  );
  int get boardings => legs.whereType<TransitLeg>().length;
  int get transfers => math.max(0, boardings - 1);
  double get estimatedFare =>
      legs.whereType<TransitLeg>().fold(0, (sum, leg) => sum + leg.fare.amount);
  String get currency {
    final transit = legs.whereType<TransitLeg>();
    return transit.isEmpty ? 'PEN' : transit.first.fare.currency;
  }
}
