import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../domain/auth/auth_failure.dart';
import '../../../../../shared/brand/brand_assets.dart';
import '../../../../../shared/l10n/l10n.dart';
import '../../../../../shared/l10n/auth_error_text.dart';
import '../../../../providers/app_providers.dart';
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
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController(),
      _name = TextEditingController();
  bool _loading = false, _register = false, _obscure = true;
  String? _error;
  @override
  void dispose() {
    for (final c in [_email, _password, _confirmation, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validEmail() =>
      _email.text.trim().length <= 254 &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim());
  Future<void> _run(
    Future<void> Function() action, {
    bool navigate = true,
    bool savePassword = false,
  }) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      if (navigate) {
        TextInput.finishAutofillContext(shouldSave: savePassword);
        widget.onSignedIn();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.authResetSent)));
      }
    } on Object catch (error) {
      if (!mounted) return;
      if (error is AuthFailure && error.code == AuthFailureCode.cancelled) {
        return;
      }
      if (error is AuthFailure &&
          error.code == AuthFailureCode.profileUpdateFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorText(error, context.l10n))),
        );
        widget.onSignedIn();
        return;
      }
      setState(() => _error = authErrorText(error, context.l10n));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_loading || !(_form.currentState?.validate() ?? false)) return;
    final auth = ref.read(authRepositoryProvider);
    await _run(
      () => _register
          ? auth.signUpWithEmail(
              email: _email.text.trim(),
              password: _password.text,
              displayName: _name.text.trim(),
            )
          : auth.signInWithEmail(
              email: _email.text.trim(),
              password: _password.text,
            ),
      savePassword: true,
    );
  }

  Future<void> _reset() async {
    if (!_validEmail()) {
      setState(() => _error = context.l10n.authInvalidEmail);
      return;
    }
    await _run(
      () => ref
          .read(authRepositoryProvider)
          .sendPasswordReset(email: _email.text.trim()),
      navigate: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, enabled = ref.watch(useFirebaseProvider);
    return AuthLayout(
      leading: widget.onBackToOnboarding == null
          ? null
          : TextButton.icon(
              onPressed: _loading ? null : widget.onBackToOnboarding,
              icon: const Icon(Icons.arrow_back),
              label: Text(l.back),
            ),
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                BrandAssets.logo,
                width: 88,
                height: 88,
                cacheWidth: 176,
              ),
              const SizedBox(height: 16),
              Text(
                enabled
                    ? (_register ? l.createAccount : l.signIn)
                    : l.guestEntry,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                enabled ? l.authAccountHelp : l.authLocalHelp,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (enabled) ...[
                if (_register) ...[
                  TextFormField(
                    key: const ValueKey('auth.name'),
                    controller: _name,
                    enabled: !_loading,
                    autofillHints: const [AutofillHints.name],
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l.authName),
                    validator: (value) =>
                        value == null ||
                            value.trim().length < 2 ||
                            value.trim().length > 60
                        ? l.authNameInvalid
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  key: const ValueKey('auth.email'),
                  controller: _email,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l.email),
                  validator: (_) => _validEmail() ? null : l.authInvalidEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('auth.password'),
                  controller: _password,
                  enabled: !_loading,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: [
                    _register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: l.password,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      tooltip: _obscure
                          ? l.authShowPassword
                          : l.authHidePassword,
                    ),
                  ),
                  textInputAction: _register
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_register) _submit();
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? l.authPasswordRequired
                      : value.length > 128 || (_register && value.length < 8)
                      ? l.authPasswordLength
                      : null,
                ),
                if (_register) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('auth.confirmation'),
                    controller: _confirmation,
                    enabled: !_loading,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l.authConfirmPassword,
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) =>
                        value != _password.text ? l.authPasswordsDiffer : null,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const ValueKey('auth.submit'),
                  onPressed: _loading ? null : _submit,
                  child: Text(_register ? l.createAccount : l.signIn),
                ),
                TextButton(
                  key: const ValueKey('auth.mode'),
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                          _register = !_register;
                          _error = null;
                          _password.clear();
                          _confirmation.clear();
                          _form.currentState?.reset();
                        }),
                  child: Text(_register ? l.authHaveAccount : l.createAccount),
                ),
                if (!_register)
                  TextButton(
                    key: const ValueKey('auth.reset'),
                    onPressed: _loading ? null : _reset,
                    child: Text(l.authForgotPassword),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('auth.google'),
                  onPressed: _loading
                      ? null
                      : () => _run(
                          ref.read(authRepositoryProvider).signInWithGoogle,
                        ),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: Text(l.authGoogle),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                key: const ValueKey('auth.guest'),
                onPressed: _loading
                    ? null
                    : () => _run(
                        ref.read(authRepositoryProvider).signInAnonymously,
                      ),
                child: Text(l.guestEntry),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    key: const ValueKey('auth.error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
