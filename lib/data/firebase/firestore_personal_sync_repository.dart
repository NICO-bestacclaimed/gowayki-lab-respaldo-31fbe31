import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../../domain/repositories/personal_sync_repository.dart';
import '../../domain/sync/personal_record.dart';

class FirestorePersonalSyncRepository implements PersonalSyncRepository {
  FirestorePersonalSyncRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      _db.collection('users').doc(uid).collection('state');
  String _id(String key) => sha256.convert(utf8.encode(key)).toString();
  @override
  Stream<PersonalRemoteSnapshot> watch(
    String uid,
  ) => _items(uid).snapshots(includeMetadataChanges: true).map((snapshot) {
    // Abort on malformed data; never replace a valid local library with emptiness.
    final records = snapshot.docs
        .map((doc) => PersonalRecord.fromJson(doc.data()))
        .toList();
    return PersonalRemoteSnapshot(
      records,
      fromServer:
          !snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites,
    );
  });
  @override
  Future<List<PersonalRecord>> push(
    String uid,
    List<PersonalRecord> records,
  ) async {
    final winners = <PersonalRecord>[];
    // Bound transaction size and perform all its reads before any writes.
    for (var offset = 0; offset < records.length; offset += 20) {
      final group = records.skip(offset).take(20).toList();
      winners.addAll(
        await _db.runTransaction<List<PersonalRecord>>(
          (transaction) async {
            final docs = <DocumentSnapshot<Map<String, dynamic>>>[];
            for (final record in group) {
              docs.add(await transaction.get(_items(uid).doc(_id(record.key))));
            }
            final result = <PersonalRecord>[];
            for (var i = 0; i < group.length; i++) {
              final local = group[i], data = docs[i].data();
              final remote = data == null
                  ? null
                  : PersonalRecord.fromJson(data);
              if (remote == null || local.compareTo(remote) > 0) {
                transaction.set(docs[i].reference, local.toJson());
                result.add(local);
              } else {
                result.add(remote);
              }
            }
            return result;
          },
          timeout: const Duration(seconds: 12),
          maxAttempts: 3,
        ),
      );
    }
    return winners;
  }
}
