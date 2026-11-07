import '../planner/itinerary.dart';

class PositionFix {
  PositionFix({
    required this.point,
    required this.accuracyMeters,
    required this.at,
    this.heading,
  });
  final GeoPoint point;
  final double accuracyMeters;
  final double? heading;
  final DateTime at;
}

abstract interface class PositionRepository {
  Future<bool> serviceEnabled();
  Future<PositionFix> current();
  Stream<PositionFix> watch();
  Future<bool> openServiceSettings();
}
