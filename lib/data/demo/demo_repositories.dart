import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/auth_user.dart';
import '../../core/models/city.dart';
import '../../core/models/feedback_item.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/city_repository.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../domain/repositories/preferences_repository.dart';

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
