import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/infra/auth/auth_operations.dart';
import 'package:gowayki_lab/data/firebase/firebase_auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gowayki_lab/data/firebase/firebase_account_deletion_repository.dart';
import 'package:gowayki_lab/domain/auth/auth_failure.dart';
import 'package:gowayki_lab/domain/repositories/google_identity_repository.dart';

class Info extends Fake implements fb.UserInfo {
  Info(this.providerId);
  @override
  final String providerId;
}

class Person extends Fake implements fb.User {
  Person({this.isAnonymous = false, this.provider = 'password'});
  final String provider;
  @override
  final bool isAnonymous;
  @override
  String get uid => 'alice';
  @override
  String? get email => 'fixture@example.test';
  @override
  List<fb.UserInfo> get providerData => [Info(provider)];
  String? fail;
  final calls = <String>[];
  @override
  Future<fb.UserCredential> reauthenticateWithCredential(
    fb.AuthCredential credential,
  ) async {
    calls.add(credential.providerId);
    if (fail != null) throw fb.FirebaseAuthException(code: fail!);
    return Credential();
  }
}

class Credential extends Fake implements fb.UserCredential {}

class Auth extends Fake implements fb.FirebaseAuth {
  Auth(this.user);
  final Person user;
  @override
  fb.User? get currentUser => user;
}

class Google implements GoogleIdentityRepository {
  int requests = 0;
  @override
  Future<String> authenticateIdToken() async {
    requests++;
    return 'fixture-id-token';
  }

  @override
  Future<void> signOut() async {}
}

class Database extends Fake implements FirebaseFirestore {}

void main() {
  test(
    'native sign-in waits until deletion releases its verified identity',
    () async {
      final operations = AuthOperations(), person = Person(), google = Google();
      final backend = Auth(person);
      final deletion = FirebaseAccountDeletionRepository(
        auth: backend,
        firestore: Database(),
        google: google,
        operations: operations,
      );
      final login = FirebaseAuthRepository(
        auth: backend,
        google: google,
        operations: operations,
      );
      await deletion.prepare('alice', password: 'Fixture');
      var finished = false;
      final pending = login.signInAnonymously().then((_) {
        finished = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(finished, false);
      deletion.discardPreparation();
      await pending;
      expect(finished, true);
    },
  );
  test(
    'Auth lock is released after failures and release is idempotent',
    () async {
      final gate = AuthOperations();
      await expectLater(
        gate.run<void>(() async {
          throw StateError('Fixture');
        }),
        throwsStateError,
      );
      final lease = await gate.acquire();
      lease.release();
      lease.release();
      expect(await gate.run(() async => 42), 42);
    },
  );
  test(
    'password and Google verify the current identity before any Firestore access',
    () async {
      final person = Person(), google = Google();
      final repository = FirebaseAccountDeletionRepository(
        auth: Auth(person),
        firestore: Database(),
        google: google,
      );
      await repository.prepare('alice', password: 'Fixture');
      expect(person.calls, ['password']);
      expect(google.requests, 0);
      repository.discardPreparation();
      await expectLater(
        repository.erase('alice'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.cancelled,
          ),
        ),
      );
      final googlePerson = Person(provider: 'google.com');
      final other = FirebaseAccountDeletionRepository(
        auth: Auth(googlePerson),
        firestore: Database(),
        google: google,
      );
      await other.prepare('alice');
      expect(google.requests, 1);
      expect(googlePerson.calls, ['google.com']);
      other.discardPreparation();
    },
  );
  test(
    'failed verification and a mismatched uid cannot start cloud erasure',
    () async {
      final person = Person()..fail = 'wrong-password';
      final repository = FirebaseAccountDeletionRepository(
        auth: Auth(person),
        firestore: Database(),
        google: Google(),
      );
      await expectLater(
        repository.prepare('alice', password: 'Wrong'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.invalidCredentials,
          ),
        ),
      );
      await expectLater(repository.erase('alice'), throwsA(isA<AuthFailure>()));
      await expectLater(
        repository.prepare('bob', password: 'Fixture'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.cancelled,
          ),
        ),
      );
    },
  );
  test(
    'anonymous deletion needs no invented password or Google sign-in',
    () async {
      final person = Person(isAnonymous: true), google = Google();
      final repository = FirebaseAccountDeletionRepository(
        auth: Auth(person),
        firestore: Database(),
        google: google,
      );
      await repository.prepare('alice');
      expect(person.calls, isEmpty);
      expect(google.requests, 0);
      repository.discardPreparation();
    },
  );
}
