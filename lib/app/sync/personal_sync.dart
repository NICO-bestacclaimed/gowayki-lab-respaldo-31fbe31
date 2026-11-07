import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/firebase/firestore_personal_sync_repository.dart';
import '../../domain/repositories/personal_sync_repository.dart';
import '../../domain/sync/personal_record.dart';
import '../providers/app_providers.dart';
import 'personal_data.dart';
import 'account_deletion_state.dart';

enum SyncStatus {
  local,
  needsSession,
  waiting,
  syncing,
  synced,
  unavailable,
  deleting,
}

final personalSyncRepositoryProvider = Provider<PersonalSyncRepository>(
  (ref) => FirestorePersonalSyncRepository(),
);
final personalSyncProvider =
    NotifierProvider<PersonalSyncController, SyncStatus>(
      PersonalSyncController.new,
    );

class PersonalSyncController extends Notifier<SyncStatus> {
  StreamSubscription<PersonalRemoteSnapshot>? _subscription;
  Timer? _timer;
  var _generation = 0, _failures = 0;
  bool _ready = false, _busy = false, _again = false;
  final _writes = <Future<void>>{};
  Map<String, PersonalRecord> _remote = {};
  @override
  SyncStatus build() {
    final scope = ref.watch(personalScopeProvider);
    final enabled = ref.watch(useFirebaseProvider);
    final generation = ++_generation;
    _ready = false;
    _busy = false;
    _again = false;
    _remote = {};
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    ref.onDispose(() {
      ++_generation;
      _timer?.cancel();
      unawaited(_subscription?.cancel());
    });
    if (!enabled) return SyncStatus.local;
    if (scope.uid == null) return SyncStatus.needsSession;
    final jobs = ref.watch(accountDeletionJobsProvider);
    if (jobs.isLoading) return SyncStatus.waiting;
    if (jobs.hasError) return SyncStatus.unavailable;
    if (jobs.requireValue.contains(scope.uid)) return SyncStatus.deleting;
    ref.listen(personalDataProvider, (previous, next) {
      if (next.hasValue && _current(generation)) {
        _schedule(scope.uid!, generation);
      }
    });
    Future.microtask(() => _start(scope.uid!, generation));
    return SyncStatus.waiting;
  }

  bool _current(int generation) => ref.mounted && generation == _generation;
  Future<void> _start(String uid, int generation) async {
    try {
      await ref.read(personalDataProvider.future);
      if (!_current(generation)) return;
      _subscription = ref
          .read(personalSyncRepositoryProvider)
          .watch(uid)
          .listen((snapshot) async {
            if (!_current(generation)) return;
            try {
              _remote = PersonalRecord.merge(_remote.values, snapshot.records);
              await ref
                  .read(personalDataProvider.notifier)
                  .mergeRemote(snapshot.records);
              if (!_current(generation)) return;
              if (snapshot.fromServer) {
                _ready = true;
                _failures = 0;
              }
              _schedule(uid, generation);
            } on Object {
              _failed(uid, generation);
            }
          }, onError: (Object error) => _failed(uid, generation));
      // Missing database/network must not leave a permanent spinner.
      _timer = Timer(const Duration(seconds: 15), () {
        if (_current(generation) && !_ready) state = SyncStatus.unavailable;
      });
    } on Object {
      _failed(uid, generation);
    }
  }

  void _schedule(String uid, int generation) {
    if (!_current(generation) || !_ready) return;
    if (_busy) {
      _again = true;
      return;
    }
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 250),
      () => _flush(uid, generation),
    );
  }

  Future<void> _flush(String uid, int generation) async {
    if (!_current(generation) || !_ready || _busy) return;
    _busy = true;
    _again = false;
    final turn = Completer<void>();
    _writes.add(turn.future);
    try {
      final data = await ref.read(personalDataProvider.future);
      if (!_current(generation)) return;
      final pending = data.records.values
          .where(
            (r) => _remote[r.key] == null || r.compareTo(_remote[r.key]!) > 0,
          )
          .toList();
      if (pending.isEmpty) {
        state = SyncStatus.synced;
        return;
      }
      state = SyncStatus.syncing;
      final winners = await ref
          .read(personalSyncRepositoryProvider)
          .push(uid, pending);
      if (!_current(generation)) return;
      _remote = PersonalRecord.merge(_remote.values, winners);
      await ref.read(personalDataProvider.notifier).mergeRemote(winners);
      if (!_current(generation)) return;
      _failures = 0;
      state = SyncStatus.synced;
    } on Object {
      _failed(uid, generation);
    } finally {
      _writes.remove(turn.future);
      turn.complete();
      if (_current(generation)) {
        _busy = false;
        if (_again) _schedule(uid, generation);
      }
    }
  }

  void _failed(String uid, int generation) {
    if (!_current(generation)) return;
    state = SyncStatus.unavailable;
    _timer?.cancel();
    // Bounded retries. The profile always offers an explicit retry afterwards.
    if (_failures++ < 3) {
      _timer = Timer(Duration(seconds: 5 * _failures), () {
        if (!_current(generation)) return;
        if (_ready) {
          _flush(uid, generation);
        } else {
          retry();
        }
      });
    }
  }

  Future<void> settle() async {
    await Future.wait(_writes.toList());
  }

  void retry() {
    ref.invalidateSelf();
  }
}
