import '../repositories/position_repository.dart';

abstract interface class TripTrackingRepository {
  bool get supported;

  /// Called only after disclosure, location/notification consent and GPS checks,
  /// while the application is resumed. Cancelling the stream stops the service.
  Stream<PositionFix> watch({required String title, required String body});
}
