import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowayki_lab/app/game/weekly_scores.dart';
import 'package:gowayki_lab/app/sync/account_deletion_controller.dart';
import 'package:gowayki_lab/app/sync/account_deletion_state.dart';
import 'package:gowayki_lab/app/sync/personal_data.dart';
import 'package:gowayki_lab/app/sync/personal_sync.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/providers/planner_providers.dart';
import 'package:gowayki_lab/core/models/auth_user.dart';
import 'package:gowayki_lab/domain/auth/auth_failure.dart';
import 'package:gowayki_lab/domain/game/game_message.dart';
import 'package:gowayki_lab/domain/game/weekly_ranking.dart';
import 'package:gowayki_lab/domain/repositories/auth_repository.dart';
import 'package:gowayki_lab/domain/repositories/account_deletion_repository.dart';
import 'package:gowayki_lab/domain/repositories/ranking_repository.dart';
import 'package:gowayki_lab/domain/repositories/personal_sync_repository.dart';

class Session extends Fake implements AuthRepository {
  AuthUser? user = const AuthUser(
    id: 'alice',
    email: 'fixture@example.test',
    displayName: 'Cuenta de prueba',
    providers: ['password'],
  );
  final events = StreamController<AuthUser?>.broadcast();
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> observeSession() async* {
    yield user;
    yield* events.stream;
  }

  void set(AuthUser? value) {
    user = value;
    events.add(value);
  }

  @override
  Future<void> signOut() async {
    set(null);
  }
}

class Ranking implements RankingRepository {
  bool fail = false;
  Completer<void>? paused;
  final calls = <({String uid, String name, PendingScore score})>[];
  @override
  Future<WeeklyRanking> load(String week, {String? uid}) async =>
      const WeeklyRanking(top: []);
  @override
  Future<int> publish(String uid, String name, PendingScore score) async {
    calls.add((uid: uid, name: name, score: score));
    await paused?.future;
    if (fail) throw StateError('Offline fixture');
    return score.score;
  }
}

class DeleteRepository implements AccountDeletionRepository {
  DeleteRepository(this.session);
  final Session session;
  bool badPassword = false, failCleanup = false;
  final calls = <String>[];
  @override
  void discardPreparation() {}
  @override
  Future<void> prepare(String uid, {String? password}) async {
    calls.add('verify:$uid');
    if (badPassword) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }
  }

  @override
  Future<void> erase(String uid) async {
    calls.add('erase:$uid');
    if (failCleanup) throw StateError('Simulated interruption');
    await session.signOut();
  }
}

class Sync extends Fake implements PersonalSyncRepository {
  int pushes = 0;
  Completer<void>? paused;
  @override
  Stream<PersonalRemoteSnapshot> watch(String uid) =>
      Stream.value(const PersonalRemoteSnapshot([], fromServer: true));
  @override
  Future<List<Never>> push(String uid, List records) async {
    pushes++;
    await paused?.future;
    return [];
  }
}

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 150; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late Session session;
  late Ranking ranking;
  late DeleteRepository deletion;
  late Sync sync;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = Session();
    ranking = Ranking();
    deletion = DeleteRepository(session);
    sync = Sync();
    container = ProviderContainer(
      overrides: [
        useFirebaseProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(session),
        rankingRepositoryProvider.overrideWithValue(ranking),
        accountDeletionRepositoryProvider.overrideWithValue(deletion),
        personalSyncRepositoryProvider.overrideWithValue(sync),
        appClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 7, 16)),
      ],
    );
    container.listen(authStateProvider, (_, next) {});
    await container.read(authStateProvider.future);
    await container.read(accountDeletionJobsProvider.future);
    await container.read(personalDataProvider.future);
    await container.read(weeklyScoresProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await session.events.close();
  });
  test(
    'erasure waits for a pending personal-data upload before wiping the cloud',
    () async {
      sync.paused = Completer<void>();
      await container
          .read(personalDataProvider.notifier)
          .edit((c) => {'line:private': true});
      container.listen(personalSyncProvider, (_, next) {});
      await until(() => sync.pushes == 1);
      final removal = container
          .read(accountDeletionControllerProvider.notifier)
          .erase('alice', password: 'fixture');
      await until(
        () => container
            .read(accountDeletionJobsProvider)
            .requireValue
            .contains('alice'),
      );
      expect(deletion.calls, ['verify:alice']);
      sync.paused!.complete();
      await removal;
      expect(deletion.calls, ['verify:alice', 'erase:alice']);
      expect(session.currentUser, isNull);
    },
  );
  test(
    'erasure drains an in-flight ranking upload before removing cloud data',
    () async {
      ranking.paused = Completer<void>();
      await container
          .read(weeklyScoresProvider.notifier)
          .record(GameScore(100, 90000));
      await until(() => ranking.calls.isNotEmpty);
      final removal = container
          .read(accountDeletionControllerProvider.notifier)
          .erase('alice', password: 'fixture');
      await until(
        () => container
            .read(accountDeletionJobsProvider)
            .requireValue
            .contains('alice'),
      );
      expect(deletion.calls, ['verify:alice']);
      ranking.paused!.complete();
      await removal;
      expect(deletion.calls, ['verify:alice', 'erase:alice']);
      expect(session.currentUser, isNull);
    },
  );
  test('ISO week uses Lima midnight, including year boundaries', () {
    expect(rankingWeek(DateTime.utc(2021, 1, 4, 4, 59)), 'arequipa_2020-W53');
    expect(rankingWeek(DateTime.utc(2021, 1, 4, 5)), 'arequipa_2021-W01');
    expect(rankingWeek(DateTime.utc(2022, 1, 1, 17)), 'arequipa_2021-W52');
    expect(rankingWeek(DateTime.utc(2026, 11, 7, 16)), 'arequipa_2026-W45');
  });
  test(
    'invalid weekly payloads are rejected and duplicate weeks keep the best score',
    () {
      expect(
        () => PendingScore.fromJson({
          'week': 'arequipa_2026-W99',
          'score': 100,
          'durationMs': 90000,
        }),
        throwsFormatException,
      );
      expect(
        () => PendingScore.fromJson({
          'week': 'arequipa_2026-W45',
          'score': 5001,
          'durationMs': 90000,
        }),
        throwsFormatException,
      );
      expect(
        () => PendingScore.fromJson({
          'week': 'arequipa_2026-W45',
          'score': 5000,
          'durationMs': 1000,
        }),
        throwsFormatException,
      );
      final state = WeeklyScoreState.decode(
        '[{"week":"arequipa_2026-W45","score":100,"durationMs":90000},{"week":"arequipa_2026-W45","score":50,"durationMs":90000}]',
      );
      expect(state.pending.values.single.score, 100);
    },
  );
  test(
    'offline weekly scores remain durable and retry publishes only the best score',
    () async {
      ranking.fail = true;
      await container
          .read(weeklyScoresProvider.notifier)
          .record(GameScore(100, 90000));
      await container
          .read(weeklyScoresProvider.notifier)
          .record(GameScore(50, 90000));
      await until(
        () =>
            container.read(weeklyScoresProvider).asData?.value.failed ?? false,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        WeeklyScoreState.decode(
          prefs.getString(weeklyStorageKey('alice')),
        ).pending.values.single.score,
        100,
      );
      ranking.fail = false;
      container.read(weeklyScoresProvider.notifier).retry();
      await until(
        () => container.read(weeklyScoresProvider).requireValue.pending.isEmpty,
      );
      expect(ranking.calls.last.score.score, 100);
      expect(ranking.calls.last.uid, 'alice');
      expect(ranking.calls.last.name, 'Cuenta de prueba');
      expect(
        WeeklyScoreState.decode(
          prefs.getString(weeklyStorageKey('alice')),
        ).pending,
        isEmpty,
      );
    },
  );
  test(
    'score arriving while an upload is in flight is not removed by the old acknowledgement',
    () async {
      ranking.paused = Completer<void>();
      await container
          .read(weeklyScoresProvider.notifier)
          .record(GameScore(100, 90000));
      await until(() => ranking.calls.isNotEmpty);
      await container
          .read(weeklyScoresProvider.notifier)
          .record(GameScore(200, 90000));
      ranking.paused!.complete();
      await until(
        () => container.read(weeklyScoresProvider).requireValue.pending.isEmpty,
      );
      expect(ranking.calls.last.score.score, 200);
    },
  );
  test(
    'switching account cannot publish old queued points as the new user',
    () async {
      ranking.paused = Completer<void>();
      await container
          .read(weeklyScoresProvider.notifier)
          .record(GameScore(100, 90000));
      await until(() => ranking.calls.isNotEmpty);
      session.set(
        const AuthUser(
          id: 'bob',
          email: 'peer@example.test',
          displayName: 'Otra cuenta',
        ),
      );
      await until(() => container.read(personalScopeProvider).uid == 'bob');
      await container.read(weeklyScoresProvider.future);
      ranking.paused!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(
        container.read(weeklyScoresProvider).requireValue.pending,
        isEmpty,
      );
      expect(ranking.calls.map((c) => c.uid), everyElement('alice'));
      final prefs = await SharedPreferences.getInstance();
      expect(
        WeeklyScoreState.decode(
          prefs.getString(weeklyStorageKey('alice')),
        ).pending,
        isNotEmpty,
      );
    },
  );
  test(
    'failed identity verification leaves local data untouched and starts no erasure',
    () async {
      await container
          .read(personalDataProvider.notifier)
          .edit((c) => {'line:private': true});
      deletion.badPassword = true;
      await expectLater(
        container
            .read(accountDeletionControllerProvider.notifier)
            .erase('alice', password: 'bad'),
        throwsA(isA<AuthFailure>()),
      );
      expect(deletion.calls, ['verify:alice']);
      expect(container.read(accountDeletionJobsProvider).requireValue, isEmpty);
      expect(linesFrom(container.read(personalDataProvider).requireValue), {
        'private',
      });
      expect(container.read(accountDeletionControllerProvider), false);
    },
  );
  test(
    'interrupted erasure pauses cloud sync across restart and blocks resurrection',
    () async {
      await container
          .read(personalDataProvider.notifier)
          .edit((c) => {'line:private': true});
      deletion.failCleanup = true;
      await expectLater(
        container
            .read(accountDeletionControllerProvider.notifier)
            .erase('alice', password: 'fixture'),
        throwsStateError,
      );
      expect(container.read(accountDeletionJobsProvider).requireValue, {
        'alice',
      });
      expect(
        linesFrom(await container.read(personalDataProvider.future)),
        isEmpty,
      );
      await expectLater(
        container
            .read(personalDataProvider.notifier)
            .edit((c) => {'line:new': true}),
        throwsStateError,
      );
      expect(container.read(personalSyncProvider), SyncStatus.deleting);
      expect(sync.pushes, 0);
      container.invalidate(accountDeletionJobsProvider);
      await container.read(accountDeletionJobsProvider.future);
      expect(container.read(accountDeletionJobsProvider).requireValue, {
        'alice',
      });
      deletion.failCleanup = false;
      await container
          .read(accountDeletionControllerProvider.notifier)
          .erase('alice', password: 'fixture');
      expect(session.currentUser, isNull);
      expect(container.read(accountDeletionJobsProvider).requireValue, isEmpty);
      expect(container.read(accountDeletionControllerProvider), false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('personal.user.alice.v1'), isNull);
      expect(prefs.getBool(deletionFlag('alice')), isNull);
    },
  );
  test('erasure clears only its UID cache and queued scores', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('personal.user.bob.v1', 'peer-data');
    await prefs.setString(weeklyStorageKey('bob'), 'peer-score');
    await container
        .read(weeklyScoresProvider.notifier)
        .record(GameScore(100, 90000));
    await container
        .read(accountDeletionControllerProvider.notifier)
        .erase('alice', password: 'fixture');
    expect(prefs.getString('personal.user.bob.v1'), 'peer-data');
    expect(prefs.getString(weeklyStorageKey('bob')), 'peer-score');
    expect(prefs.getString(weeklyStorageKey('alice')), isNull);
    expect(deletion.calls, ['verify:alice', 'erase:alice']);
  });
}
