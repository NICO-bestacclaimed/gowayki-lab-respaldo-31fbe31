import 'package:flutter/material.dart';

import '../../../../../core/models/feedback_item.dart';
import '../../../../../data/service_locator.dart';
import '../../../../../shared/theme/theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe al menos 5 caracteres')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final city = await ServiceLocator.preferences.readCityCode();
      await ServiceLocator.feedback.submit(
        FeedbackItem(kind: _kind, message: text, cityCode: city),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias. Comentario enviado.')),
      );
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ayuda y comentarios')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SegmentedButton<FeedbackKind>(
            segments: const [
              ButtonSegment(value: FeedbackKind.bug, label: Text('Bug')),
              ButtonSegment(value: FeedbackKind.idea, label: Text('Idea')),
              ButtonSegment(value: FeedbackKind.other, label: Text('Otro')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _message,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Mensaje',
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}
