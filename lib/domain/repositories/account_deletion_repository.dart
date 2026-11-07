abstract interface class AccountDeletionRepository {
  Future<void> prepare(String uid, {String? password});
  Future<void> erase(String uid);
  void discardPreparation();
}
