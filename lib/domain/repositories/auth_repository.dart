import '../../core/models/auth_user.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> observeSession();
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  });
  Future<void> signInWithGoogle();
  Future<void> sendPasswordReset({required String email});
  Future<void> signInAnonymously();
  Future<void> signOut();
}
