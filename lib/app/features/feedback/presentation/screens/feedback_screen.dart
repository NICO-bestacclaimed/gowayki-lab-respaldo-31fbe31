import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/models/feedback_item.dart';
import '../../../../../infra/device/feedback_metadata.dart';
import '../../../../../shared/l10n/l10n.dart';
import '../../../../providers/app_providers.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});
  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  FeedbackKind _kind = FeedbackKind.idea;
  bool _sending = false;
  String? _id, _error;
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final metadata = await ref.read(feedbackMetadataProvider.future);
      final random = Random.secure();
      _id ??= List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await ref
          .read(feedbackRepositoryProvider)
          .submit(
            FeedbackItem(
              id: _id,
              kind: _kind,
              message: _message.text.trim(),
              metadata: metadata,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.feedbackSent)));
      Navigator.of(context).pop();
    } on Object {
      if (mounted) setState(() => _error = context.l10n.feedbackSendError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n,
        enabled = ref.watch(useFirebaseProvider),
        user = ref.watch(authStateProvider).asData?.value;
    final AsyncValue<FeedbackMetadata> metadata = enabled
        ? ref.watch(feedbackMetadataProvider)
        : const AsyncLoading<FeedbackMetadata>();
    return Scaffold(
      appBar: AppBar(title: Text(l.help)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!enabled) Text(l.communityLocalOnly),
              if (enabled && user == null) ...[
                Text(l.feedbackNeedsSession),
                TextButton(
                  onPressed: () => context.push('/acceso?regresar=1'),
                  child: Text(l.signIn),
                ),
              ],
              DropdownButtonFormField<FeedbackKind>(
                key: const ValueKey('feedback.kind'),
                initialValue: _kind,
                itemHeight: null,
                isExpanded: true,
                items: [
                  for (final kind in FeedbackKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(switch (kind) {
                        FeedbackKind.bug => l.feedbackBug,
                        FeedbackKind.idea => l.feedbackIdea,
                        FeedbackKind.incorrectData => l.feedbackIncorrectData,
                        FeedbackKind.other => l.feedbackOther,
                      }),
                    ),
                ],
                onChanged: _sending
                    ? null
                    : (kind) => setState(() {
                        _kind = kind!;
                        _id = null;
                      }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('feedback.message'),
                controller: _message,
                enabled: !_sending,
                maxLength: 2000,
                maxLines: 6,
                onChanged: (_) => _id = null,
                decoration: InputDecoration(labelText: l.message),
                validator: (text) =>
                    (text?.trim().length ?? 0) < 3 ? l.feedbackMinimum : null,
              ),
              Text(l.feedbackMetadataNotice),
              if (metadata.asData?.value case final FeedbackMetadata info)
                Text(
                  '${info.appVersion} · ${info.deviceModel} · ${l.dataVersion(info.dataVersion)}',
                ),
              if (metadata.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(feedbackMetadataProvider),
                  child: Text(l.retry),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('feedback.send'),
                onPressed:
                    enabled && user != null && metadata.hasValue && !_sending
                    ? _submit
                    : null,
                child: Text(_sending ? l.communityLoading : l.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
