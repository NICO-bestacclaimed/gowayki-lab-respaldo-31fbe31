import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowayki_lab/data/firebase/firebase_auth_repository.dart';
import 'package:gowayki_lab/domain/auth/auth_failure.dart';
import 'package:gowayki_lab/domain/repositories/google_identity_repository.dart';

class ProviderInfo extends Fake implements fb.UserInfo {
  ProviderInfo(this.providerId, this.uid);
  @override
  final String providerId;
  @override
  final String uid;
}

class Credential extends Fake implements fb.UserCredential {
  Credential(this.user);
  @override
  final fb.User? user;
}

class Account extends Fake implements fb.User {
  Account(
    this.auth,
    this.uid, {
    this.isAnonymous = false,
    this.email,
    this.displayName,
  });
  final Backend auth;
  @override
  final String uid;
  @override
  bool isAnonymous;
  @override
  String? email;
  @override
  String? displayName;
  @override
  String? get photoURL => null;
  final providers = <fb.UserInfo>[];
  String? linkError;
  bool nameError = false;
  @override
  List<fb.UserInfo> get providerData => providers;
  @override
  Future<fb.UserCredential> linkWithCredential(
    fb.AuthCredential credential,
  ) async {
    auth.calls.add('link:${credential.providerId}');
    if (linkError != null) throw fb.FirebaseAuthException(code: linkError!);
    isAnonymous = false;
    providers.add(ProviderInfo(credential.providerId, uid));
    auth.user = this;
    return Credential(this);
  }

  @override
  Future<void> updateDisplayName(String? value) async {
    if (nameError) {
      throw fb.FirebaseAuthException(code: 'network-request-failed');
    }
    displayName = value;
  }
}

class Backend extends Fake implements fb.FirebaseAuth {
  Account? user;
  final calls = <String>[];
  String? error;
  bool newNameError = false;
  @override
  Account? get currentUser => user;
  void check() {
    if (error != null) {
      final code = error!;
      error = null;
      throw fb.FirebaseAuthException(code: code);
    }
  }

  @override
  Stream<fb.User?> userChanges() => Stream.value(user);
  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    calls.add('email:$email');
    check();
    user = Account(this, 'existing', email: email);
    return Credential(user);
  }

  @override
  Future<fb.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    calls.add('create:$email');
    check();
    user = Account(this, 'new', email: email)..nameError = newNameError;
    return Credential(user);
  }

  @override
  Future<fb.UserCredential> signInWithCredential(
    fb.AuthCredential credential,
  ) async {
    calls.add('credential:${credential.providerId}');
    check();
    user = Account(this, 'existing-google', email: 'fixture@example.test');
    return Credential(user);
  }

  @override
  Future<fb.UserCredential> signInAnonymously() async {
    calls.add('anonymous');
    check();
    user = Account(this, 'guest', isAnonymous: true);
    return Credential(user);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    fb.ActionCodeSettings? actionCodeSettings,
  }) async {
    calls.add('reset:$email');
    check();
  }

  @override
  Future<void> signOut() async {
    calls.add('out');
    check();
    user = null;
  }
}

class Google extends Fake implements GoogleIdentityRepository {
  bool cancelled = false, failSignOut = false;
  @override
  Future<String> authenticateIdToken() async {
    if (cancelled) throw const AuthFailure(AuthFailureCode.cancelled);
    return 'fixture-token';
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) throw StateError('SDK unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Backend backend;
  late Google google;
  late FirebaseAuthRepository repository;
  setUp(() {
    backend = Backend();
    google = Google();
    repository = FirebaseAuthRepository(auth: backend, google: google);
  });
  Matcher failure(AuthFailureCode code) =>
      isA<AuthFailure>().having((e) => e.code, 'code', code);
  test(
    'registration upgrades the guest with linkWithCredential and preserves UID and local favorites',
    () async {
      SharedPreferences.setMockInitialValues({
        'favorites.line_ids': ['fixture-line'],
      });
      final prefs = await SharedPreferences.getInstance();
      backend.user = Account(backend, 'guest-id', isAnonymous: true);
      await repository.signUpWithEmail(
        email: ' fixture@example.test ',
        password: 'Fixture-Pass-123',
        displayName: ' Ana ',
      );
      expect(backend.calls, ['link:password']);
      expect(repository.currentUser!.id, 'guest-id');
      expect(repository.currentUser!.isAnonymous, isFalse);
      expect(repository.currentUser!.displayName, 'Ana');
      expect(repository.currentUser!.providers, ['password']);
      expect(prefs.getStringList('favorites.line_ids'), ['fixture-line']);
    },
  );
  test(
    'new registration creates an account and stores the name supplied by the user',
    () async {
      await repository.signUpWithEmail(
        email: 'fixture@example.test',
        password: 'Fixture-Pass-123',
        displayName: 'Ana',
      );
      expect(backend.calls, ['create:fixture@example.test']);
      expect(repository.currentUser!.displayName, 'Ana');
    },
  );
  test('Google upgrades a guest without changing UID', () async {
    backend.user = Account(backend, 'guest-id', isAnonymous: true);
    await repository.signInWithGoogle();
    expect(backend.calls, ['link:google.com']);
    expect(repository.currentUser!.id, 'guest-id');
    expect(repository.currentUser!.isAnonymous, isFalse);
  });
  test(
    'existing Google account signs in after link collision and leaves local favorites intact',
    () async {
      SharedPreferences.setMockInitialValues({
        'favorites.line_ids': ['fixture-line'],
      });
      final prefs = await SharedPreferences.getInstance();
      backend.user = Account(backend, 'guest-id', isAnonymous: true)
        ..linkError = 'credential-already-in-use';
      await repository.signInWithGoogle();
      expect(backend.calls, ['link:google.com', 'credential:google.com']);
      expect(repository.currentUser!.id, 'existing-google');
      expect(prefs.getStringList('favorites.line_ids'), ['fixture-line']);
    },
  );
  test(
    'Google cancel never calls Firebase and does not block the next action',
    () async {
      google.cancelled = true;
      await expectLater(
        repository.signInWithGoogle(),
        throwsA(failure(AuthFailureCode.cancelled)),
      );
      expect(backend.calls, isEmpty);
      await repository.signInAnonymously();
      expect(backend.calls, ['anonymous']);
    },
  );
  test('reset hides missing account and translates network failures', () async {
    backend.error = 'user-not-found';
    await repository.sendPasswordReset(email: ' fixture@example.test ');
    expect(backend.calls, ['reset:fixture@example.test']);
    backend.error = 'network-request-failed';
    await expectLater(
      repository.sendPasswordReset(email: 'fixture@example.test'),
      throwsA(failure(AuthFailureCode.network)),
    );
  });
  test(
    'backend errors are typed and credentials are not included in domain error messages',
    () async {
      for (final entry in {
        'invalid-credential': AuthFailureCode.invalidCredentials,
        'email-already-in-use': AuthFailureCode.emailInUse,
        'weak-password': AuthFailureCode.weakPassword,
        'operation-not-allowed': AuthFailureCode.methodUnavailable,
        'too-many-requests': AuthFailureCode.tooManyRequests,
      }.entries) {
        backend.error = entry.key;
        await expectLater(
          repository.signInWithEmail(
            email: 'fixture@example.test',
            password: 'Fixture-Pass-123',
          ),
          throwsA(failure(entry.value)),
        );
      }
    },
  );
  test(
    'guest request preserves a current session and signout clears Firebase even when Google cleanup fails',
    () async {
      backend.user = Account(backend, 'guest', isAnonymous: true);
      await repository.signInAnonymously();
      expect(backend.calls, isEmpty);
      google.failSignOut = true;
      await repository.signOut();
      expect(repository.currentUser, isNull);
      expect(await repository.observeSession().first, isNull);
    },
  );
  test(
    'profile update failure reports that the account was already created',
    () async {
      backend.newNameError = true;
      await expectLater(
        repository.signUpWithEmail(
          email: 'fixture@example.test',
          password: 'Fixture-Pass-123',
          displayName: 'Ana',
        ),
        throwsA(failure(AuthFailureCode.profileUpdateFailed)),
      );
      expect(repository.currentUser!.id, 'new');
    },
  );
}
