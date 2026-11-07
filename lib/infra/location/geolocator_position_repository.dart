import 'package:geolocator/geolocator.dart';
import '../../domain/planner/itinerary.dart';
import '../../domain/repositories/position_repository.dart';

class GeolocatorPositionRepository implements PositionRepository {
  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );
  PositionFix _fix(Position p) => PositionFix(
    point: GeoPoint(p.latitude, p.longitude),
    accuracyMeters: p.accuracy,
    at: p.timestamp,
    heading: p.heading.isFinite && p.heading >= 0 ? p.heading : null,
  );
  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<PositionFix> current() async => _fix(
    await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    ),
  );
  @override
  Stream<PositionFix> watch() =>
      Geolocator.getPositionStream(locationSettings: _settings).map(_fix);
  @override
  Future<bool> openServiceSettings() => Geolocator.openLocationSettings();
}
