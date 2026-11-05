abstract interface class PreferencesRepository {
  Future<String?> readCityCode();
  Future<void> saveCityCode(String code);
  Future<String?> readLocaleCode();
  Future<void> saveLocaleCode(String? code);
}
