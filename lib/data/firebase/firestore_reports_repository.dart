import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/community/community_report.dart';
import '../../domain/repositories/reports_repository.dart';

class FirestoreReportsRepository implements ReportsRepository {
  FirestoreReportsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  @override
  String newId() => _db.collection('reports').doc().id;
  Stream<ReportFeed> _watch(Query<Map<String, dynamic>> query) =>
      query.snapshots(includeMetadataChanges: true).map((snapshot) {
        final rows = <CommunityReport>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data(), created = data['createdAt'];
            if (created is! Timestamp) continue;
            rows.add(
              CommunityReport.fromMap(doc.id, {
                ...data,
                'createdAt': created.toDate(),
              }),
            );
          } on Object {
            /* An invalid public document must not break the offline map. */
          }
        }
        return ReportFeed(
          List.unmodifiable(rows),
          fromCache: snapshot.metadata.isFromCache,
        );
      });
  @override
  Stream<ReportFeed> watchActive(DateTime since) => _watch(
    _db
        .collection('reports')
        .where('cityCode', isEqualTo: 'arequipa')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('createdAt', descending: true),
  );
  @override
  Stream<ReportFeed> watchMine(String uid) => _watch(
    _db
        .collection('reports')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true),
  );
  String _uid() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const CommunityException(CommunityFailure.needsAccount);
    }
    return user.uid;
  }

  @override
  Future<void> create(ReportDraft draft) async {
    draft.validate();
    final uid = _uid(), doc = _db.collection('reports').doc(draft.id);
    await _db.runTransaction(
      (tx) async {
        final existing = await tx.get(doc);
        if (_uid() != uid) {
          throw const CommunityException(CommunityFailure.needsAccount);
        }
        if (existing.exists) {
          if (existing.data()?['uid'] != uid) {
            throw const CommunityException(CommunityFailure.invalid);
          }
          return;
        }
        tx.set(doc, {
          'uid': uid,
          'cityCode': 'arequipa',
          'type': draft.kind.apiValue,
          'description': draft.description.trim(),
          'latitude': draft.latitude,
          'longitude': draft.longitude,
          'createdAt': FieldValue.serverTimestamp(),
          'confirmations': 0,
          if (draft.stopId != null) 'stopId': draft.stopId,
          if (draft.lineId != null) 'lineId': draft.lineId,
        });
      },
      timeout: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }

  @override
  Future<bool> confirm(String reportId) async {
    final uid = _uid(),
        doc = _db.collection('reports').doc(reportId),
        marker = _db
            .collection('reports')
            .doc(reportId)
            .collection('confirmations')
            .doc(uid),
        index = _db
            .collection('users')
            .doc(uid)
            .collection('confirmationRefs')
            .doc(reportId);
    return _db.runTransaction(
      (tx) async {
        final report = await tx.get(doc), vote = await tx.get(marker);
        if (_uid() != uid) {
          throw const CommunityException(CommunityFailure.needsAccount);
        }
        if (!report.exists) {
          throw const CommunityException(CommunityFailure.expired);
        }
        final data = report.data()!, created = data['createdAt'];
        if (created is! Timestamp ||
            !created
                .toDate()
                .add(const Duration(hours: 72))
                .isAfter(DateTime.now().toUtc())) {
          throw const CommunityException(CommunityFailure.expired);
        }
        if (vote.exists) return false;
        tx.update(doc, {'confirmations': (data['confirmations'] as int) + 1});
        tx.set(marker, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
        tx.set(index, {'id': reportId});
        return true;
      },
      timeout: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }

  @override
  Future<void> delete(String reportId) async {
    final uid = _uid(), doc = _db.collection('reports').doc(reportId);
    await _db.runTransaction(
      (tx) async {
        final report = await tx.get(doc);
        if (_uid() != uid || report.data()?['uid'] != uid) {
          throw const CommunityException(CommunityFailure.needsAccount);
        }
        tx.delete(doc);
      },
      timeout: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }
}
