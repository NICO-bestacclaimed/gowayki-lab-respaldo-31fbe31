import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/preferences_repository.dart';

class FirestorePreferencesRepository implements PreferencesRepository {
  FirestorePreferencesRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('preferences')
        .doc('settings');
  }

  @override
  Future<String?> readCityCode() async {
    final doc = _doc;
    if (doc == null) return null;
    return (await doc.get()).data()?['city_code'] as String?;
  }

  @override
  Future<void> saveCityCode(String code) async {
    final doc = _doc;
    if (doc == null) return;
    await doc.set({'city_code': code}, SetOptions(merge: true));
  }

  @override
  Future<String?> readLocaleCode() async {
    final doc = _doc;
    if (doc == null) return null;
    return (await doc.get()).data()?['locale'] as String?;
  }

  @override
  Future<void> saveLocaleCode(String? code) async {
    final doc = _doc;
    if (doc == null) return;
    await doc.set({'locale': code}, SetOptions(merge: true));
  }
}
