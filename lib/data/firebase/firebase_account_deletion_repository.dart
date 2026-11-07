import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/auth/auth_failure.dart';
import '../../domain/repositories/account_deletion_repository.dart';
import '../../domain/repositories/google_identity_repository.dart';
import '../../infra/auth/google_identity_repository.dart';
import '../../infra/auth/auth_operations.dart';
import 'firebase_auth_repository.dart';

class FirebaseAccountDeletionRepository implements AccountDeletionRepository {
  FirebaseAccountDeletionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    GoogleIdentityRepository? google,
    AuthOperations? operations,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _google = google ?? PlatformGoogleIdentityRepository(),
       _operations = operations ?? firebaseAuthOperations;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final GoogleIdentityRepository _google;
  final AuthOperations _operations;
  AuthLease? _lease;
  String? _prepared;
  AuthCredential? _credential;
  DateTime? _verified;
  User _user(String uid) {
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) {
      throw const AuthFailure(AuthFailureCode.cancelled);
    }
    return user;
  }

  @override
  Future<void> prepare(String uid, {String? password}) async {
    if (_lease != null) throw const AuthFailure(AuthFailureCode.cancelled);
    _prepared = null;
    _credential = null;
    _lease = await _operations.acquire();
    try {
      final user = _user(uid);
      if (!user.isAnonymous) {
        final providers = user.providerData.map((p) => p.providerId).toSet();
        if (providers.contains('password') &&
            password != null &&
            password.isNotEmpty) {
          _credential = EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          );
        } else if (providers.contains('google.com')) {
          _credential = GoogleAuthProvider.credential(
            idToken: await _google.authenticateIdToken(),
          );
        } else {
          throw const AuthFailure(AuthFailureCode.invalidCredentials);
        }
        await user.reauthenticateWithCredential(_credential!);
      }
      _user(uid);
      _prepared = uid;
      _verified = DateTime.now();
    } on FirebaseAuthException catch (error) {
      discardPreparation();
      throw firebaseAuthFailure(error.code);
    } on Object {
      discardPreparation();
      rethrow;
    }
  }

  @override
  void discardPreparation() {
    _lease?.release();
    _lease = null;
    _prepared = null;
    _credential = null;
    _verified = null;
  }

  Future<void> _plainCollection(String uid, String section) async {
    final collection = _db.collection('users').doc(uid).collection(section);
    while (true) {
      _user(uid);
      final rows = await collection
          .limit(100)
          .get(const GetOptions(source: Source.server));
      if (rows.docs.isEmpty) return;
      _user(uid);
      final batch = _db.batch();
      for (final row in rows.docs) {
        batch.delete(row.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _feedback(String uid) async {
    final refs = _db.collection('users').doc(uid).collection('feedbackRefs');
    while (true) {
      _user(uid);
      final rows = await refs
          .limit(4)
          .get(const GetOptions(source: Source.server));
      if (rows.docs.isEmpty) return;
      _user(uid);
      final batch = _db.batch();
      for (final row in rows.docs) {
        batch.delete(_db.collection('feedback').doc(row.id));
        batch.delete(row.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _confirmations(String uid) async {
    final refs = _db
        .collection('users')
        .doc(uid)
        .collection('confirmationRefs');
    while (true) {
      _user(uid);
      final rows = await refs
          .limit(100)
          .get(const GetOptions(source: Source.server));
      if (rows.docs.isEmpty) return;
      for (final row in rows.docs) {
        _user(uid);
        final report = _db.collection('reports').doc(row.id),
            marker = _db
                .collection('reports')
                .doc(row.id)
                .collection('confirmations')
                .doc(uid);
        await _db.runTransaction(
          (tx) async {
            final parent = await tx.get(report),
                vote = await tx.get(marker),
                index = await tx.get(row.reference);
            _user(uid);
            if (!index.exists) return;
            if (vote.exists) {
              if (parent.exists) {
                final count = parent.data()!['confirmations'] as int;
                if (count < 1) {
                  throw StateError('Inconsistent confirmation counter');
                }
                tx.update(report, {'confirmations': count - 1});
              }
              tx.delete(marker);
            }
            tx.delete(row.reference);
          },
          timeout: const Duration(seconds: 12),
          maxAttempts: 3,
        );
      }
    }
  }

  Future<void> _reports(String uid) async {
    while (true) {
      _user(uid);
      final rows = await _db
          .collection('reports')
          .where('uid', isEqualTo: uid)
          .limit(100)
          .get(const GetOptions(source: Source.server));
      if (rows.docs.isEmpty) return;
      _user(uid);
      final batch = _db.batch();
      for (final row in rows.docs) {
        batch.delete(row.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _scores(String uid) async {
    final refs = _db.collection('users').doc(uid).collection('scoreRefs');
    while (true) {
      _user(uid);
      final rows = await refs
          .limit(5)
          .get(const GetOptions(source: Source.server));
      if (rows.docs.isEmpty) return;
      _user(uid);
      final batch = _db.batch();
      for (final row in rows.docs) {
        batch.delete(
          _db
              .collection('leaderboards')
              .doc(row.id)
              .collection('scores')
              .doc(uid),
        );
        batch.delete(row.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> erase(String uid) async {
    if (_prepared != uid) throw const AuthFailure(AuthFailureCode.cancelled);
    final root = _db.collection('users').doc(uid);
    final marker = _db.collection('deletedAccounts').doc(uid);
    try {
      _user(uid);
      final sealed = (await marker.get(
        const GetOptions(source: Source.server),
      )).exists;
      if (!sealed) {
        await _db.runTransaction(
          (tx) async {
            final previous = await tx.get(root);
            _user(uid);
            if (previous.data()?['deleting'] == true) return;
            tx.set(root, {
              'deleting': true,
              'deletionStartedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          },
          timeout: const Duration(seconds: 12),
          maxAttempts: 3,
        );
      }
      await _feedback(uid);
      await _confirmations(uid);
      await _reports(uid);
      await _scores(uid);
      for (final section in ['state', 'library', 'preferences']) {
        await _plainCollection(uid, section);
      }
      final user = _user(uid);
      if (_credential != null &&
          DateTime.now().difference(_verified!).inMinutes >= 4) {
        await user.reauthenticateWithCredential(_credential!);
      }
      // Firestore and Auth do not share a transaction. A failed attempt remains
      // suspended locally and can resume; each cleanup operation is idempotent.
      if (!sealed) {
        final seal = _db.batch();
        seal.set(marker, <String, dynamic>{});
        seal.delete(root);
        await seal.commit();
      }
      try {
        await _user(uid).delete();
      } on FirebaseAuthException catch (error) {
        if (error.code == 'user-not-found') {
          if (_auth.currentUser?.uid == uid) await _auth.signOut();
        } else {
          rethrow;
        }
      }
      try {
        if (_auth.currentUser == null || _auth.currentUser?.uid == uid) {
          await _google.signOut();
        }
      } on Object {
        /* Auth was deleted successfully. */
      }
    } on FirebaseAuthException catch (error) {
      throw firebaseAuthFailure(error.code);
    } finally {
      _prepared = null;
      _credential = null;
      _verified = null;
    }
  }
}
