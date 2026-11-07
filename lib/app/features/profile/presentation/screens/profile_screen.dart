import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../providers/app_providers.dart';
import '../../../game/game_screen.dart';
import '../../../../game/game_preferences.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user =
        ref.watch(authStateProvider).asData?.value ??
        ref.read(authRepositoryProvider).currentUser;
    final guest = user?.id == 'demo-anon';
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profile)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 36,
              child: Icon(Icons.person_outline, size: 36),
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
              child: Text(context.l10n.signIn),
            ),
          ] else ...[
            Text(
              guest ? context.l10n.guest : (user.displayName ?? user.email),
              textAlign: TextAlign.center,
            ),
            if (!guest) Text(user.email, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/perfil');
              },
              child: Text(context.l10n.signOut),
            ),
          ],
          const SizedBox(height: 24),
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
