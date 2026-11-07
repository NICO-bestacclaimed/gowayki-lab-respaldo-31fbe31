import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/l10n/l10n.dart';
import 'personal_sync.dart';

class PersonalSyncTile extends ConsumerWidget {
  const PersonalSyncTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(personalSyncProvider);
    final l = context.l10n;
    final text = switch (status) {
      SyncStatus.deleting => l.accountDeletionPending,
      SyncStatus.local => l.syncLocal,
      SyncStatus.needsSession => l.syncNeedsSession,
      SyncStatus.waiting => l.syncWaiting,
      SyncStatus.syncing => l.syncWorking,
      SyncStatus.synced => l.syncDone,
      SyncStatus.unavailable => l.syncUnavailable,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Icon(
            status == SyncStatus.synced
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
          ),
          title: Text(l.syncTitle),
          subtitle: Text(text),
        ),
        if (status == SyncStatus.unavailable)
          OutlinedButton(
            onPressed: () => ref.read(personalSyncProvider.notifier).retry(),
            child: Text(l.syncRetry),
          ),
      ],
    );
  }
}
