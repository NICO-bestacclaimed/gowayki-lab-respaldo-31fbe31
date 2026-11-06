import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../common/ui/layouts/auth_layout.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    super.key,
    required this.onSignedIn,
    this.onBackToOnboarding,
  });

  final VoidCallback onSignedIn;
  final VoidCallback? onBackToOnboarding;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
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
              label: Text(context.l10n.back),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.pets_rounded, size: 72, color: AppColors.primary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Gowayki Lab',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.brandTagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: context.l10n.email),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: context.l10n.password),
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
                    () => ref
                        .read(authRepositoryProvider)
                        .signInWithEmail(
                          email: _email.text.trim(),
                          password: _password.text,
                        ),
                  ),
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(context.l10n.continueAction),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _loading
                ? null
                : () => _run(
                    () => ref
                        .read(authRepositoryProvider)
                        .signUpWithEmail(
                          email: _email.text.trim(),
                          password: _password.text,
                          displayName: 'Wayki',
                        ),
                  ),
            child: Text(context.l10n.createAccount),
          ),
          TextButton(
            onPressed: _loading
                ? null
                : () =>
                      _run(ref.read(authRepositoryProvider).signInAnonymously),
            child: Text(context.l10n.guestEntry),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            ref.read(useFirebaseProvider)
                ? context.l10n.firebaseActive
                : context.l10n.localDemo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
