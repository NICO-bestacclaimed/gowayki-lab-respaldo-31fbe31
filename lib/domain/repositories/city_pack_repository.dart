import '../models/city_pack_models.dart';
import 'transit_network_repository.dart';

abstract interface class CityPackRepository
    implements TransitNetworkRepository {
  Future<List<CityStop>> stops({int limit = 100, int offset = 0});
  Future<CityStop?> stop(String id);
  Future<List<CityPattern>> patternsForLine(String lineId);
  Future<List<CityPatternStop>> patternStops(String patternId);
  Future<CityShape?> shape(String shapeId);
  Future<List<CityTransfer>> transfersFrom(String stopId);
  Future<List<CityPlace>> searchPlaces(String query, {int limit = 20});
  Future<Map<String, Object?>> configuration();
  Future<CityFare?> fareForLine(String lineId);
  Future<CityPackInfo> packageInfo();
  Future<void> close();
}
