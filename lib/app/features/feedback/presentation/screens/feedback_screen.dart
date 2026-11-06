import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/feedback_item.dart';
import '../../../../providers/app_providers.dart';
import '../../../../../shared/theme/theme.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  FeedbackKind _kind = FeedbackKind.idea;
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _message.text.trim();
    if (text.length < 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.feedbackMinimum)));
      return;
    }
    setState(() => _sending = true);
    try {
      final city = await ref.read(preferencesRepositoryProvider).readCityCode();
      await ref
          .read(feedbackRepositoryProvider)
          .submit(FeedbackItem(kind: _kind, message: text, cityCode: city));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.feedbackSent)));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(context.l10n.help)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SegmentedButton<FeedbackKind>(
            segments: [
              ButtonSegment(
                value: FeedbackKind.bug,
                label: Text(context.l10n.feedbackBug),
              ),
              ButtonSegment(
                value: FeedbackKind.idea,
                label: Text(context.l10n.feedbackIdea),
              ),
              ButtonSegment(
                value: FeedbackKind.other,
                label: Text(context.l10n.feedbackOther),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _message,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: context.l10n.message,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(context.l10n.send),
          ),
        ],
      ),
    );
  }
}
