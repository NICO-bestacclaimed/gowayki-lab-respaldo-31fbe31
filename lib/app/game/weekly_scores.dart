import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/firebase/firestore_ranking_repository.dart';
import '../../domain/repositories/ranking_repository.dart';
import '../../domain/game/weekly_ranking.dart';
import '../../domain/game/game_message.dart';
import '../providers/app_providers.dart';
import '../providers/planner_providers.dart';
import '../settings/app_settings.dart';
import '../sync/personal_data.dart';
import '../sync/account_deletion_state.dart';

final rankingRepositoryProvider = Provider<RankingRepository>(
  (ref) => FirestoreRankingRepository(),
);
final rankingWeekProvider = Provider.autoDispose<String>((ref) {
  final now = ref.watch(appClockProvider)().toUtc(),
      lima = ref
          .watch(appClockProvider)()
          .toUtc()
          .subtract(const Duration(hours: 5));
  final next = DateTime.utc(
    lima.year,
    lima.month,
    lima.day,
  ).add(Duration(days: 8 - lima.weekday, hours: 5));
  final timer = Timer(
    next.difference(now) + const Duration(milliseconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return rankingWeek(now);
});
final weeklyRankingProvider = FutureProvider.autoDispose<WeeklyRanking?>((
  ref,
) async {
  if (!ref.watch(useFirebaseProvider)) return null;
  final scope = ref.watch(personalScopeProvider);
  final week = ref.watch(rankingWeekProvider);
  return ref
      .watch(rankingRepositoryProvider)
      .load(week, uid: scope.uid)
      .timeout(const Duration(seconds: 15));
});

class WeeklyScoreState {
  WeeklyScoreState({
    Map<String, PendingScore> pending = const {},
    this.failed = false,
    this.paused = false,
  }) : pending = Map.unmodifiable(pending);
  final Map<String, PendingScore> pending;
  final bool failed, paused;
  String encode() => jsonEncode(pending.values.map((r) => r.toJson()).toList());
  factory WeeklyScoreState.decode(String? text) {
    final rows = jsonDecode(text ?? '[]') as List;
    final pending = <String, PendingScore>{};
    for (final row in rows) {
      final score = PendingScore.fromJson(Map<String, dynamic>.from(row));
      final previous = pending[score.week];
      if (previous == null || score.score > previous.score) {
        pending[score.week] = score;
      }
    }
    return WeeklyScoreState(pending: pending);
  }
}

final weeklyScoresProvider =
    AsyncNotifierProvider<WeeklyScores, WeeklyScoreState>(
      WeeklyScores.new,
      retry: (count, error) => null,
    );

class WeeklyScores extends AsyncNotifier<WeeklyScoreState> {
  late SharedPreferences _prefs;
  String? _uid;
  int _generation = 0, _failures = 0;
  bool _busy = false;
  final _writes = <Future<void>>{};
  Future<void>? _pending;
  Timer? _timer;
  @override
  Future<WeeklyScoreState> build() async {
    final scope = ref.watch(personalScopeProvider),
        enabled = ref.watch(useFirebaseProvider);
    final generation = ++_generation;
    _uid = scope.uid;
    _busy = false;
    _timer?.cancel();
    ref.onDispose(() {
      ++_generation;
      _timer?.cancel();
    });
    if (!enabled || scope.uid == null) return WeeklyScoreState(paused: true);
    final jobs = ref.watch(accountDeletionJobsProvider);
    if (jobs.isLoading) return WeeklyScoreState(paused: true);
    if (jobs.hasError) return WeeklyScoreState(paused: true, failed: true);
    if (jobs.requireValue.contains(scope.uid)) {
      return WeeklyScoreState(paused: true);
    }
    _prefs = await ref.watch(localSettingsStorageProvider.future);
    if (!ref.mounted || generation != _generation) {
      return WeeklyScoreState(paused: true);
    }
    final result = WeeklyScoreState.decode(
      _prefs.getString(weeklyStorageKey(scope.uid!)),
    );
    _timer = Timer(const Duration(milliseconds: 250), () => _flush(generation));
    return result;
  }

  Future<void> _change(
    WeeklyScoreState Function(WeeklyScoreState) change,
  ) async {
    if (state.isLoading || !state.hasValue) await future;
    final uid = _uid, generation = _generation;
    if (uid == null || state.requireValue.paused) return;
    final previous = _pending, turn = Completer<void>();
    _pending = turn.future;
    if (previous != null) await previous;
    try {
      if (!ref.mounted ||
          generation != _generation ||
          _prefs.getBool(deletionFlag(uid)) == true) {
        return;
      }
      final next = change(state.requireValue);
      if (!await _prefs.setString(weeklyStorageKey(uid), next.encode())) {
        throw StateError('Score not saved');
      }
      if (ref.mounted && generation == _generation) state = AsyncData(next);
    } finally {
      turn.complete();
      if (identical(_pending, turn.future)) _pending = null;
    }
  }

  Future<void> record(GameScore score) async {
    if (!ref.read(useFirebaseProvider) ||
        ref.read(personalScopeProvider).uid == null) {
      return;
    }
    await ref.read(accountDeletionJobsProvider.future);
    final week = rankingWeek(ref.read(appClockProvider)());
    await _change((old) {
      final previous = old.pending[week];
      if (previous != null && previous.score >= score.value) return old;
      return WeeklyScoreState(
        pending: {
          ...old.pending,
          week: PendingScore.fromJson(
            PendingScore(
              week,
              score.value,
              score.durationMs,
            ).toJson().cast<String, dynamic>(),
          ),
        },
      );
    });
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final generation = _generation;
    _timer = Timer(const Duration(milliseconds: 250), () => _flush(generation));
  }

  Future<void> _flush(int generation) async {
    bool current() => ref.mounted && generation == _generation;
    if (!current() ||
        _busy ||
        !state.hasValue ||
        state.requireValue.paused ||
        state.requireValue.pending.isEmpty) {
      return;
    }
    final uid = _uid!;
    _busy = true;
    final turn = Completer<void>();
    _writes.add(turn.future);
    try {
      final auth = ref.read(authRepositoryProvider).currentUser;
      if (auth?.id != uid) return;
      final name = auth!.displayName?.trim();
      for (final score in state.requireValue.pending.values.toList()) {
        if (!current() || _prefs.getBool(deletionFlag(uid)) == true) return;
        final best = await ref
            .read(rankingRepositoryProvider)
            .publish(
              uid,
              name == null || name.isEmpty ? 'Invitado' : name,
              score,
            );
        if (!current()) return;
        await _change((old) {
          final pending = {...old.pending};
          if ((pending[score.week]?.score ?? 0) <= best) {
            pending.remove(score.week);
          }
          return WeeklyScoreState(pending: pending);
        });
      }
      if (current()) {
        _failures = 0;
        ref.invalidate(weeklyRankingProvider);
      }
    } on Object {
      if (current()) {
        state = AsyncData(
          WeeklyScoreState(pending: state.requireValue.pending, failed: true),
        );
        if (_failures++ < 3) {
          _timer = Timer(
            Duration(seconds: 5 * _failures),
            () => _flush(generation),
          );
        }
      }
    } finally {
      _writes.remove(turn.future);
      turn.complete();
      if (current()) _busy = false;
    }
    if (current() &&
        !state.requireValue.failed &&
        state.requireValue.pending.isNotEmpty) {
      _schedule();
    }
  }

  void retry() {
    _failures = 0;
    _schedule();
  }

  Future<void> settle() async {
    if (state.isLoading) {
      try {
        await future;
      } on Object {
        /* Deletion may clear an invalid queue. */
      }
    }
    await Future.wait(_writes.toList());
    final pending = _pending;
    if (pending != null) await pending;
  }
}
