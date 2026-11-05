import '../../core/models/city.dart';

abstract interface class CityRepository {
  Future<List<City>> activeCities();
}
