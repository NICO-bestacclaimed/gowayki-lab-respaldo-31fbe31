import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/city_pack_repository.dart';
import '../domain/repositories/city_repository.dart';
import '../domain/repositories/feedback_repository.dart';
import '../domain/repositories/place_search_repository.dart';
import '../domain/repositories/preferences_repository.dart';
import '../domain/repositories/transit_network_repository.dart';
import '../infra/city_pack/city_pack_installer.dart';
import '../infra/city_pack/city_pack_place_search_repository.dart';
import '../infra/city_pack/sqlite_city_pack_repository.dart';
import 'demo/demo_repositories.dart';
import 'firebase/firebase_auth_repository.dart';
import 'firebase/firestore_city_repository.dart';
import 'firebase/firestore_feedback_repository.dart';
import 'firebase/firestore_preferences_repository.dart';

/// Resources owned by one ProviderScope, with no static mutable singleton.
class AppServices {
  AppServices._({
    required this.useFirebase,
    required this.localPreferences,
    required this.cityPack,
    required this.auth,
    required this.cities,
    required this.preferences,
    required this.feedback,
  }) : places = CityPackPlaceSearchRepository(cityPack);
  final bool useFirebase;
  final SharedPreferences localPreferences;
  final CityPackRepository cityPack;
  final AuthRepository auth;
  final CityRepository cities;
  final PreferencesRepository preferences;
  final FeedbackRepository feedback;
  final PlaceSearchRepository places;
  TransitNetworkRepository get transit => cityPack;
  Future<void>? _closing;

  static Future<AppServices> open({
    required bool useFirebase,
    CityPackInstaller? installer,
    CityPackRepository? cityPackRepository,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pack =
        cityPackRepository ??
        await SqliteCityPackRepository.open(installer: installer);
    try {
      return AppServices._(
        useFirebase: useFirebase,
        localPreferences: prefs,
        cityPack: pack,
        auth: useFirebase ? FirebaseAuthRepository() : DemoAuthRepository(),
        cities: useFirebase ? FirestoreCityRepository() : DemoCityRepository(),
        preferences: useFirebase
            ? FirestorePreferencesRepository()
            : DemoPreferencesRepository(prefs),
        feedback: useFirebase
            ? FirestoreFeedbackRepository()
            : DemoFeedbackRepository(),
      );
    } on Object {
      await pack.close();
      rethrow;
    }
  }

  Future<void> close() => _closing ??= _finishClose();
  Future<void> _finishClose() async {
    try {
      await cityPack.close();
    } finally {
      if (auth case final DemoAuthRepository demo) await demo.close();
    }
  }
}
