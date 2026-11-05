import '../../core/models/place_result.dart';
import '../../core/models/trip_option.dart';

abstract interface class TripPlanRepository {
  Future<List<TripOption>> plan({
    required PlaceResult origin,
    required PlaceResult destination,
  });
}
