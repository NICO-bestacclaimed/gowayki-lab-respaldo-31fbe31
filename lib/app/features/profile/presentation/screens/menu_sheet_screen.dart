import 'package:flutter/material.dart';

import '../../../../../data/service_locator.dart';
import '../../../../../shared/theme/theme.dart';

/// Menú lateral / sheet (interfaz tipo perfil Gowayki).
class MenuSheetScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final user = ServiceLocator.auth.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Menú')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.primary,
              child: Text(_initial(user?.displayName ?? user?.email)),
            ),
            title: Text(user?.displayName ?? 'Wayki'),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenProfile,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Ajustes'),
            onTap: onOpenSettings,
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Ayuda y comentarios'),
            onTap: onOpenFeedback,
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              await ServiceLocator.auth.signOut();
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
