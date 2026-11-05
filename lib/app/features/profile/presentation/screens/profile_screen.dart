import 'package:flutter/material.dart';

import '../../../../../data/service_locator.dart';
import '../../../../../shared/theme/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = ServiceLocator.auth.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryContainer,
              child: Icon(Icons.person, size: 40, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            title: const Text('Nombre'),
            subtitle: Text(user?.displayName ?? '—'),
          ),
          ListTile(
            title: const Text('Correo'),
            subtitle: Text(user?.email ?? '—'),
          ),
        ],
      ),
    );
  }
}
