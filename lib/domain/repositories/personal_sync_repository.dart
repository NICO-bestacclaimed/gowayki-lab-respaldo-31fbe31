import '../sync/personal_record.dart';

class PersonalRemoteSnapshot {
  const PersonalRemoteSnapshot(this.records, {required this.fromServer});
  final List<PersonalRecord> records;
  final bool fromServer;
}

abstract interface class PersonalSyncRepository {
  Stream<PersonalRemoteSnapshot> watch(String uid);

  /// Compares every revision inside a server transaction before writing it.
  Future<List<PersonalRecord>> push(String uid, List<PersonalRecord> records);
}
