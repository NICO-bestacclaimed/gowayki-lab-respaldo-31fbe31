import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../core/models/auth_user.dart';
import '../../domain/auth/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/google_identity_repository.dart';
import '../../infra/auth/google_identity_repository.dart';

AuthFailure firebaseAuthFailure(String code) => AuthFailure(switch (code) {
  'invalid-email' => AuthFailureCode.invalidEmail,
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'invalid-login-credentials' => AuthFailureCode.invalidCredentials,
  'weak-password' ||
  'password-does-not-meet-requirements' => AuthFailureCode.weakPassword,
  'email-already-in-use' ||
  'credential-already-in-use' => AuthFailureCode.emailInUse,
  'user-disabled' => AuthFailureCode.disabled,
  'operation-not-allowed' ||
  'configuration-not-found' => AuthFailureCode.methodUnavailable,
  'network-request-failed' => AuthFailureCode.network,
  'too-many-requests' => AuthFailureCode.tooManyRequests,
  'account-exists-with-different-credential' ||
  'provider-already-linked' => AuthFailureCode.differentProvider,
  _ => AuthFailureCode.unexpected,
});

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    fb.FirebaseAuth? auth,
    GoogleIdentityRepository? google,
  }) : _auth = auth ?? fb.FirebaseAuth.instance,
       _google = google ?? PlatformGoogleIdentityRepository();
  final fb.FirebaseAuth _auth;
  final GoogleIdentityRepository _google;
  Future<void>? _pending;
  AuthUser? _map(fb.User? user) => user == null
      ? null
      : AuthUser(
          id: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
          isAnonymous: user.isAnonymous,
          providers: user.providerData
              .map((p) => p.providerId)
              .toList(growable: false),
        );
  @override
  AuthUser? get currentUser => _map(_auth.currentUser);
  @override
  Stream<AuthUser?> observeSession() => _auth.userChanges().map(_map);
  Future<void> _run(Future<void> Function() action) async {
    final previous = _pending, turn = Completer<void>();
    _pending = turn.future;
    if (previous != null) await previous;
    try {
      await action();
    } on fb.FirebaseAuthException catch (error) {
      throw firebaseAuthFailure(error.code);
    } finally {
      turn.complete();
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _run(() async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  });
  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) => _run(() async {
    final credential = fb.EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    final before = _auth.currentUser;
    final result = before != null && before.isAnonymous
        ? await before.linkWithCredential(credential)
        : await _auth.createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      try {
        await result.user?.updateDisplayName(name);
      } on fb.FirebaseAuthException {
        throw const AuthFailure(AuthFailureCode.profileUpdateFailed);
      }
    }
  });
  @override
  Future<void> signInWithGoogle() => _run(() async {
    final token = await _google.authenticateIdToken();
    final credential = fb.GoogleAuthProvider.credential(idToken: token);
    final before = _auth.currentUser;
    if (before != null && before.isAnonymous) {
      try {
        await before.linkWithCredential(credential);
      } on fb.FirebaseAuthException catch (error) {
        if (!{
          'credential-already-in-use',
          'email-already-in-use',
        }.contains(error.code)) {
          rethrow;
        }
        await _auth.signInWithCredential(credential);
      }
    } else {
      await _auth.signInWithCredential(credential);
    }
  });
  @override
  Future<void> sendPasswordReset({required String email}) => _run(() async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') rethrow;
    }
  });
  @override
  Future<void> signInAnonymously() => _run(() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
  });
  @override
  Future<void> signOut() => _run(() async {
    await _auth.signOut();
    try {
      await _google.signOut();
    } on Object {
      /* Firebase session has already ended. */
    }
  });
}
