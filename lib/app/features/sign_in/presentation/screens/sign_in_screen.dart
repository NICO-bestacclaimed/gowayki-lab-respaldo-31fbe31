import 'package:flutter/material.dart';

import '../../../../../data/service_locator.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../common/ui/layouts/auth_layout.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.onSignedIn,
    this.onBackToOnboarding,
  });

  final VoidCallback onSignedIn;
  final VoidCallback? onBackToOnboarding;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController(text: 'wayki@gowayki.lab');
  final _password = TextEditingController(text: 'demo1234');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) widget.onSignedIn();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      leading: widget.onBackToOnboarding == null
          ? null
          : TextButton.icon(
              onPressed: widget.onBackToOnboarding,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              label: const Text('Volver'),
              style: TextButton.styleFrom(foregroundColor: AppColors.onSurfaceMuted),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.pets_rounded, size: 72, color: AppColors.primary),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Gowayki Lab',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Tu ciudad, más cerca',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: AppSpacing.xxl),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _loading
                ? null
                : () => _run(
                      () => ServiceLocator.auth.signInWithEmail(
                        email: _email.text.trim(),
                        password: _password.text,
                      ),
                    ),
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Continuar'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _loading
                ? null
                : () => _run(
                      () => ServiceLocator.auth.signUpWithEmail(
                        email: _email.text.trim(),
                        password: _password.text,
                        displayName: 'Wayki',
                      ),
                    ),
            child: const Text('Crear cuenta'),
          ),
          TextButton(
            onPressed: _loading
                ? null
                : () => _run(ServiceLocator.auth.signInAnonymously),
            child: const Text('Entrar como invitado'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            ServiceLocator.useFirebase
                ? 'Firebase Auth activo'
                : 'Modo demo · sin Firebase',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
