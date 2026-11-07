import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/models/auth_user.dart';
import '../../../../../domain/auth/auth_failure.dart';
import '../../../../../shared/l10n/l10n.dart';
import '../../../../../shared/l10n/auth_error_text.dart';
import '../../../../sync/account_deletion_controller.dart';

class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key, required this.user});
  final AuthUser user;
  @override
  ConsumerState<DeleteAccountDialog> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends ConsumerState<DeleteAccountDialog> {
  final _password = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _error = null);
    try {
      await ref
          .read(accountDeletionControllerProvider.notifier)
          .erase(widget.user.id, password: _password.text);
      if (mounted) Navigator.pop(context, true);
    } on AuthFailure catch (error) {
      if (mounted && error.code != AuthFailureCode.cancelled) {
        setState(() => _error = authErrorText(error, context.l10n));
      }
    } on Object {
      if (mounted) setState(() => _error = context.l10n.accountDeletionError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n,
        busy = ref.watch(accountDeletionControllerProvider),
        google = widget.user.providers.contains('google.com');
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(l.deleteAccount),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.accountDeletionWarning),
              const SizedBox(height: 8),
              Text(l.accountDeletionMarkerNotice),
              const SizedBox(height: 12),
              if (!widget.user.isAnonymous && !google)
                TextField(
                  key: const ValueKey('account.delete.password'),
                  controller: _password,
                  enabled: !busy,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: l.password),
                ),
              if (google) Text(l.accountDeletionGoogle),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (busy)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(l.accountDeleting),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('account.delete.confirm'),
            onPressed: busy ? null : _delete,
            child: Text(l.deleteAccount),
          ),
        ],
      ),
    );
  }
}
