import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/feedback_item.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../domain/community/community_report.dart';

class FirestoreFeedbackRepository implements FeedbackRepository {
  FirestoreFeedbackRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  @override
  Future<void> submit(FeedbackItem item) async {
    final uid = _auth.currentUser?.uid, metadata = item.metadata;
    if (uid == null) {
      throw const CommunityException(CommunityFailure.needsAccount);
    }
    if (metadata == null ||
        item.message.trim().length < 3 ||
        item.message.trim().length > 2000) {
      throw const CommunityException(CommunityFailure.invalid);
    }
    final feedback = _db.collection('feedback').doc(item.id),
        index = _db
            .collection('users')
            .doc(uid)
            .collection('feedbackRefs')
            .doc(feedback.id);
    await _db.runTransaction(
      (tx) async {
        final previous = await tx.get(index);
        if (_auth.currentUser?.uid != uid) {
          throw const CommunityException(CommunityFailure.needsAccount);
        }
        if (previous.exists) {
          return; // Retry of the same form does not create duplicates.
        }
        tx.set(feedback, {
          'uid': uid,
          'kind': item.kind.apiValue,
          'message': item.message.trim(),
          'city_code': 'arequipa',
          'created_at': FieldValue.serverTimestamp(),
          'app_version': metadata.appVersion,
          'device_model': metadata.deviceModel,
          'data_version': metadata.dataVersion,
        });
        tx.set(index, {'id': feedback.id});
      },
      timeout: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }
}
