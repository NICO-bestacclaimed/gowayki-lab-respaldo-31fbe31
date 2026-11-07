import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:gowayki_lab/shared/l10n/auth_error_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../providers/app_providers.dart';
import '../../../game/game_screen.dart';
import '../../../../game/game_preferences.dart';
import '../../../../sync/personal_sync_tile.dart';
import '../../../../sync/account_deletion_controller.dart';
import '../../../../sync/account_deletion_state.dart';
import '../../../../community/community_providers.dart';
import '../../../../community/report_widgets.dart';
import 'delete_account_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user =
        ref.watch(authStateProvider).asData?.value ??
        ref.read(authRepositoryProvider).currentUser;
    final guest = user?.isAnonymous ?? false;
    final deleting = ref.watch(accountDeletionControllerProvider);
    final photo = Uri.tryParse(user?.photoUrl ?? '');
    final photoUrl =
        photo != null && photo.scheme == 'https' && photo.host.isNotEmpty
        ? photo.toString()
        : null;
    final best = ref.watch(gamePreferencesProvider).asData?.value.best ?? 0;
    final pending =
        ref.watch(useFirebaseProvider) &&
        user != null &&
        (ref
                .watch(accountDeletionJobsProvider)
                .asData
                ?.value
                .contains(user.id) ??
            false);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profile)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: SizedBox(
              width: 72,
              height: 72,
              child: ClipOval(
                child: photoUrl == null
                    ? const CircleAvatar(
                        child: Icon(Icons.person_outline, size: 36),
                      )
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => const CircleAvatar(
                          child: Icon(Icons.person_outline, size: 36),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (user == null) ...[
            Text(context.l10n.noSession, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(context.l10n.localGuestHelp, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/acceso'),
              child: Text(
                ref.watch(useFirebaseProvider)
                    ? context.l10n.signIn
                    : context.l10n.guestEntry,
              ),
            ),
          ] else ...[
            Text(
              guest ? context.l10n.guest : (user.displayName ?? user.email),
              textAlign: TextAlign.center,
            ),
            if (!guest) Text(user.email, textAlign: TextAlign.center),
            if (guest && ref.watch(useFirebaseProvider))
              OutlinedButton(
                key: const ValueKey('auth.upgrade'),
                onPressed: () => context.push('/acceso'),
                child: Text(context.l10n.authUpgrade),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: deleting
                  ? null
                  : () async {
                      try {
                        await ref.read(authRepositoryProvider).signOut();
                        if (context.mounted) context.go('/perfil');
                      } on Object catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(authErrorText(error, context.l10n)),
                            ),
                          );
                        }
                      }
                    },
              child: Text(context.l10n.signOut),
            ),
          ],
          const SizedBox(height: 12),
          const Center(child: Text('Arequipa')),
          Center(child: Text(context.l10n.gameBest(best))),
          if (ref.watch(useFirebaseProvider) && user != null) ...[
            if (!guest) _MyReports(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('account.delete'),
              onPressed: deleting
                  ? null
                  : () async {
                      final removed = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => DeleteAccountDialog(user: user),
                      );
                      if (context.mounted && removed == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.accountDeleted)),
                        );
                        context.go('/perfil');
                      }
                    },
              icon: const Icon(Icons.delete_outline),
              label: Text(
                pending
                    ? context.l10n.accountDeletionResume
                    : context.l10n.deleteAccount,
              ),
            ),
          ],
          const SizedBox(height: 24),
          const PersonalSyncTile(),
          ListTile(
            key: const ValueKey('ranking.profile'),
            leading: const Icon(Icons.leaderboard_outlined),
            title: Text(context.l10n.weeklyRanking),
            onTap: () => context.push('/ranking'),
          ),
          if (ref.watch(gameSupportedProvider))
            ListTile(
              key: const ValueKey('game.profile'),
              leading: const Icon(Icons.sports_esports_outlined),
              title: const Text('Wayki Combi'),
              subtitle: Text(
                context.l10n.gameBest(
                  ref.watch(gamePreferencesProvider).asData?.value.best ?? 0,
                ),
              ),
              onTap: () => context.push('/juego'),
            ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(context.l10n.settings),
            onTap: () => context.push('/ajustes'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(context.l10n.help),
            onTap: () => context.push('/ayuda'),
          ),
        ],
      ),
    );
  }
}

class _MyReports extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ExpansionTile(
      title: Text(l.myReports),
      children: ref
          .watch(myReportsProvider)
          .when(
            loading: () => [const LinearProgressIndicator()],
            error: (_, s) => [
              Text(l.communityUnavailable),
              TextButton(
                onPressed: () => ref.invalidate(myReportsProvider),
                child: Text(l.retry),
              ),
            ],
            data: (feed) => [
              if (feed.fromCache) Text(l.communityCached),
              if (feed.items.isEmpty && !feed.fromCache) Text(l.myReportsEmpty),
              for (final report in feed.items)
                ListTile(
                  title: Text(reportKindText(report.kind, l)),
                  subtitle: Text(
                    report.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: l.deleteReport,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l.deleteReport),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l.deleteReport),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      try {
                        await ref
                            .read(reportsRepositoryProvider)
                            .delete(report.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.reportDeleted)),
                          );
                        }
                      } on Object {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.reportDeleteError)),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
            ],
          ),
    );
  }
}
