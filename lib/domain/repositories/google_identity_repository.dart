abstract interface class GoogleIdentityRepository {
  Future<String> authenticateIdToken();
  Future<void> signOut();
}
