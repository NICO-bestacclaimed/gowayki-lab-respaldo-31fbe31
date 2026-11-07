import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/firebase/firebase_account_deletion_repository.dart';
import '../../domain/repositories/account_deletion_repository.dart';
import '../game/weekly_scores.dart';
import '../providers/app_providers.dart';
import 'account_deletion_state.dart';
import 'personal_data.dart';
import 'personal_sync.dart';

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>(
  (ref) => FirebaseAccountDeletionRepository(),
);
final accountDeletionControllerProvider =
    NotifierProvider<AccountDeletionController, bool>(
      AccountDeletionController.new,
    );

class AccountDeletionController extends Notifier<bool> {
  @override
  bool build() => false;
  Future<void> erase(String uid, {String? password}) async {
    if (state) throw StateError('Deletion already running');
    state = true;
    final repo = ref.read(accountDeletionRepositoryProvider);
    try {
      await repo.prepare(uid, password: password);
      final jobs = ref.read(accountDeletionJobsProvider.notifier);
      await jobs.start(uid);
      await ref.read(personalDataProvider.notifier).settle();
      await ref.read(personalSyncProvider.notifier).settle();
      await ref.read(weeklyScoresProvider.notifier).settle();
      await jobs.clearCaches(uid);
      ref.invalidate(personalDataProvider);
      await repo.erase(uid);
      // Re-read the SDK session before clearing the persistent suspension.
      ref.invalidate(authStateProvider);
      await ref
          .read(authStateProvider.future)
          .timeout(const Duration(seconds: 5));
      await jobs.clearCaches(uid);
      await jobs.finish(uid);
      ref.invalidate(personalDataProvider);
      ref.invalidate(weeklyScoresProvider);
    } finally {
      repo.discardPreparation();
      if (ref.mounted) state = false;
    }
  }
}
