import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/game/weekly_ranking.dart';
import '../../domain/repositories/ranking_repository.dart';

class FirestoreRankingRepository implements RankingRepository {
  FirestoreRankingRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  CollectionReference<Map<String, dynamic>> _scores(String week) =>
      _db.collection('leaderboards').doc(week).collection('scores');
  RankingScore _decode(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return RankingScore(
      uid: doc.id,
      name: data['displayName'] as String,
      score: data['score'] as int,
      durationMs: data['durationMs'] as int,
    );
  }

  @override
  Future<WeeklyRanking> load(String week, {String? uid}) async {
    final topFuture = _scores(week)
        .orderBy('score', descending: true)
        .orderBy('updatedAt')
        .limit(20)
        .get(const GetOptions(source: Source.server));
    final ownFuture = uid == null
        ? null
        : _scores(week).doc(uid).get(const GetOptions(source: Source.server));
    final top = await topFuture, own = await ownFuture;
    final mine = own?.exists == true ? _decode(own!) : null;
    final higher = mine == null
        ? null
        : (await _scores(
            week,
          ).where('score', isGreaterThan: mine.score).count().get()).count;
    return WeeklyRanking(
      top: List.unmodifiable(top.docs.map(_decode)),
      own: mine,
      position: higher == null ? null : higher + 1,
    );
  }

  @override
  Future<int> publish(String uid, String name, PendingScore score) async {
    PendingScore.fromJson(score.toJson().cast<String, dynamic>());
    final doc = _scores(score.week).doc(uid),
        index = _db
            .collection('users')
            .doc(uid)
            .collection('scoreRefs')
            .doc(score.week);
    return _db.runTransaction(
      (tx) async {
        final previous = await tx.get(doc), reference = await tx.get(index);
        if (_auth.currentUser?.uid != uid) throw StateError('Session changed');
        final best = previous.data()?['score'] as int?;
        if (best != null && best >= score.score) return best;
        if (name.trim().isEmpty) {
          throw const FormatException('Missing public display label');
        }
        final display = name.trim().substring(
          0,
          name.trim().length > 60 ? 60 : name.trim().length,
        );
        tx.set(doc, {
          'uid': uid,
          'displayName': display,
          'score': score.score,
          'durationMs': score.durationMs,
          'createdAt':
              previous.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!reference.exists) tx.set(index, {'id': score.week});
        return score.score;
      },
      timeout: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }
}
