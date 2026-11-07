import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/planner/itinerary.dart';
import '../../domain/repositories/position_repository.dart';
import '../../domain/repositories/trip_tracking_repository.dart';

class GeolocatorTripTracking implements TripTrackingRepository {
  @override
  bool get supported =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform);
  @override
  Stream<PositionFix> watch({required String title, required String body}) {
    if (!supported) throw UnsupportedError('Mobile tracking only');
    final LocationSettings settings =
        defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 3),
            maxUpdateAge: Duration.zero,
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: title,
              notificationText: body,
              notificationChannelName: 'GoWayki · Viaje en curso',
              notificationIcon: const AndroidResource(name: 'ic_trip'),
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            activityType: ActivityType.automotiveNavigation,
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
          );
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => PositionFix(
        point: GeoPoint(p.latitude, p.longitude),
        accuracyMeters: p.accuracy,
        at: p.timestamp,
        heading: p.heading >= 0 ? p.heading : null,
      ),
    );
  }
}
