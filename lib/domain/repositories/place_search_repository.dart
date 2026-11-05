import '../../core/models/place_result.dart';

abstract interface class PlaceSearchRepository {
  Future<List<PlaceResult>> search(String query);
}
