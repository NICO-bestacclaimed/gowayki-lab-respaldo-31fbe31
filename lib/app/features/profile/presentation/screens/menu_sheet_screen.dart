import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../../../../../shared/theme/theme.dart';

/// Menú lateral / sheet (interfaz tipo perfil Gowayki).
class MenuSheetScreen extends ConsumerWidget {
  const MenuSheetScreen({
    super.key,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onOpenFeedback,
    required this.onSignOut,
  });

  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenFeedback;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(authRepositoryProvider).currentUser;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(context.l10n.menu)),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.primary,
              child: Text(_initial(user?.displayName ?? user?.email)),
            ),
            title: Text(user?.displayName ?? context.l10n.guest),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenProfile,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(context.l10n.settings),
            onTap: onOpenSettings,
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: Text(context.l10n.help),
            onTap: onOpenFeedback,
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(context.l10n.signOut),
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
              onSignOut();
            },
          ),
        ],
      ),
    );
  }

  static String _initial(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return 'G';
    return t.substring(0, 1).toUpperCase();
  }
}
