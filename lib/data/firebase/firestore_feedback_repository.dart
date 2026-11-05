import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/models/feedback_item.dart';
import '../../domain/repositories/feedback_repository.dart';

class FirestoreFeedbackRepository implements FeedbackRepository {
  FirestoreFeedbackRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  @override
  Future<void> submit(FeedbackItem item) async {
    await _db.collection('feedback').add({
      'kind': item.kind.apiValue,
      'message': item.message,
      'city_code': item.cityCode,
      'uid': _auth.currentUser?.uid,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
