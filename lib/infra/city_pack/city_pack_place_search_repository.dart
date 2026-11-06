import '../../core/models/place_result.dart';
import '../../domain/repositories/city_pack_repository.dart';
import '../../domain/repositories/place_search_repository.dart';

class CityPackPlaceSearchRepository implements PlaceSearchRepository {
  const CityPackPlaceSearchRepository(this.pack);
  final CityPackRepository pack;

  @override
  Future<List<PlaceResult>> search(String query) async =>
      (await pack.searchPlaces(query))
          .map(
            (place) => PlaceResult(
              id: place.id,
              name: place.name,
              address: place.address,
              latitude: place.latitude,
              longitude: place.longitude,
            ),
          )
          .toList(growable: false);
}
