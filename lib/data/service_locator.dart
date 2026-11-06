import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/city_pack_repository.dart';
import '../domain/repositories/city_repository.dart';
import '../domain/repositories/feedback_repository.dart';
import '../domain/repositories/place_search_repository.dart';
import '../domain/repositories/preferences_repository.dart';
import '../domain/repositories/transit_network_repository.dart';
import '../domain/repositories/trip_plan_repository.dart';
import '../infra/city_pack/city_pack_place_search_repository.dart';
import '../infra/city_pack/sqlite_city_pack_repository.dart';
import 'demo/demo_repositories.dart';
import 'firebase/firebase_auth_repository.dart';
import 'firebase/firestore_city_repository.dart';
import 'firebase/firestore_feedback_repository.dart';
import 'firebase/firestore_preferences_repository.dart';

class ServiceLocator {
  ServiceLocator._();

  static late final AuthRepository auth;
  static late final CityRepository cities;
  static late final PlaceSearchRepository places;
  static late final TripPlanRepository trips;
  static late final PreferencesRepository preferences;
  static late final FeedbackRepository feedback;
  static late final TransitNetworkRepository transit;
  static late final CityPackRepository cityPack;
  static late final bool useFirebase;

  static Future<void> init({
    required bool useFirebase,
    CityPackRepository? cityPackRepository,
  }) async {
    ServiceLocator.useFirebase = useFirebase;
    final prefs = await SharedPreferences.getInstance();

    cityPack = cityPackRepository ?? await SqliteCityPackRepository.open();
    places = CityPackPlaceSearchRepository(cityPack);
    trips = DemoTripPlanRepository();
    transit = cityPack;

    if (useFirebase) {
      auth = FirebaseAuthRepository();
      cities = FirestoreCityRepository();
      preferences = FirestorePreferencesRepository();
      feedback = FirestoreFeedbackRepository();
    } else {
      auth = DemoAuthRepository();
      cities = DemoCityRepository();
      preferences = DemoPreferencesRepository(prefs);
      feedback = DemoFeedbackRepository();
    }
  }
}
