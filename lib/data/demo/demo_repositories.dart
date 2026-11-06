import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/auth_user.dart';
import '../../core/models/city.dart';
import '../../core/models/feedback_item.dart';
import '../../core/models/place_result.dart';
import '../../core/models/trip_option.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/city_repository.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../domain/repositories/place_search_repository.dart';
import '../../domain/repositories/preferences_repository.dart';
import '../../domain/repositories/trip_plan_repository.dart';

class DemoAuthRepository implements AuthRepository {
  Future<void> close() => _controller.close();
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> observeSession() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _user = AuthUser(
      id: 'demo-${email.hashCode}',
      email: email,
      displayName: email.split('@').first,
    );
    _controller.add(_user);
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) => signInWithEmail(email: email, password: password);

  @override
  Future<void> signInAnonymously() async {
    _user = const AuthUser(
      id: 'demo-anon',
      email: 'wayki@gowayki.lab',
      displayName: 'Wayki',
    );
    _controller.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }
}

class DemoCityRepository implements CityRepository {
  @override
  Future<List<City>> activeCities() async => const [
    City(
      code: 'arequipa',
      name: 'Arequipa',
      region: 'Arequipa',
      centerLat: -16.4090,
      centerLng: -71.5375,
    ),
  ];
}

class DemoPlaceSearchRepository implements PlaceSearchRepository {
  static const catalog = [
    PlaceResult(
      id: '1',
      name: 'TECSUP Arequipa',
      address: 'Av. Alfonso Ugarte, Arequipa',
      latitude: -16.3988,
      longitude: -71.5369,
    ),
    PlaceResult(
      id: '2',
      name: 'Plaza de Armas',
      address: 'Centro Histórico, Arequipa',
      latitude: -16.3988,
      longitude: -71.5369,
    ),
    PlaceResult(
      id: '3',
      name: 'Mall Aventura',
      address: 'Cerro Colorado, Arequipa',
      latitude: -16.3860,
      longitude: -71.5660,
    ),
    PlaceResult(
      id: '4',
      name: 'Terminal Terrestre',
      address: 'Jacinto Ibáñez, Arequipa',
      latitude: -16.4200,
      longitude: -71.5300,
    ),
    PlaceResult(
      id: '5',
      name: 'Yanahuara',
      address: 'Mirador de Yanahuara',
      latitude: -16.3920,
      longitude: -71.5420,
    ),
  ];

  @override
  Future<List<PlaceResult>> search(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return catalog
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.address.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }
}

class DemoTripPlanRepository implements TripPlanRepository {
  @override
  Future<List<TripOption>> plan({
    required PlaceResult origin,
    required PlaceResult destination,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return [
      TripOption(
        id: 'a',
        summary: 'Combi + caminata',
        durationMinutes: 38,
        transferCount: 1,
        legs: [
          'Caminar al paradero',
          'Línea demo → cerca de ${destination.name}',
          'Caminar al destino',
        ],
      ),
      TripOption(
        id: 'b',
        summary: 'Solo caminata',
        durationMinutes: 52,
        transferCount: 0,
        legs: ['Caminar desde ${origin.name} hasta ${destination.name}'],
      ),
    ];
  }
}

class DemoPreferencesRepository implements PreferencesRepository {
  DemoPreferencesRepository(this._prefs);
  final SharedPreferences _prefs;

  @override
  Future<String?> readCityCode() async => _prefs.getString('lab.city');

  @override
  Future<void> saveCityCode(String code) => _prefs.setString('lab.city', code);

  @override
  Future<String?> readLocaleCode() async => _prefs.getString('lab.locale');

  @override
  Future<void> saveLocaleCode(String? code) async {
    if (code == null) {
      await _prefs.remove('lab.locale');
    } else {
      await _prefs.setString('lab.locale', code);
    }
  }
}

class DemoFeedbackRepository implements FeedbackRepository {
  @override
  Future<void> submit(FeedbackItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
