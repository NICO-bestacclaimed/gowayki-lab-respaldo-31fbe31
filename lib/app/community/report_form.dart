import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/place_result.dart';
import '../../domain/community/community_report.dart';
import '../../shared/l10n/l10n.dart';
import '../providers/app_providers.dart';
import 'community_providers.dart';
import 'report_widgets.dart';

Future<void> openReportForm(
  BuildContext context, {
  required PlaceResult point,
  String? stopId,
  String? lineId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => ReportForm(point: point, stopId: stopId, lineId: lineId),
);

class ReportForm extends ConsumerStatefulWidget {
  const ReportForm({super.key, required this.point, this.stopId, this.lineId});
  final PlaceResult point;
  final String? stopId, lineId;
  @override
  ConsumerState<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<ReportForm> {
  final _form = GlobalKey<FormState>(), _text = TextEditingController();
  ReportKind _kind = ReportKind.other;
  String? _id, _error, _lineId;
  @override
  void initState() {
    super.initState();
    _lineId = widget.lineId;
  }

  bool _busy = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(reportsRepositoryProvider);
      _id ??= repository.newId();
      await repository.create(
        ReportDraft(
          id: _id!,
          kind: _kind,
          description: _text.text,
          latitude: widget.point.latitude,
          longitude: widget.point.longitude,
          stopId: widget.stopId,
          lineId: _lineId,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.reportSent)));
      Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) setState(() => _error = communityError(error, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n,
        enabled = ref.watch(useFirebaseProvider),
        user = ref.watch(authStateProvider).asData?.value;
    final allowed = enabled && user != null && !user.isAnonymous;
    final lines = ref.watch(cityLinesProvider).asData?.value ?? const [];
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.reportProblem,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(widget.point.name),
              Text(l.reportLifetime),
              const SizedBox(height: 12),
              if (!enabled)
                Text(l.communityLocalOnly)
              else if (!allowed) ...[
                Text(l.reportNeedsAccount),
                TextButton(
                  onPressed: () => context.push('/acceso?regresar=1'),
                  child: Text(l.signIn),
                ),
              ],
              DropdownButtonFormField<ReportKind>(
                initialValue: _kind,
                itemHeight: null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.reportType),
                items: [
                  for (final kind in ReportKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(
                        reportKindText(kind, l),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy || !allowed
                    ? null
                    : (value) => setState(() {
                        _kind = value!;
                        _id = null;
                      }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('report.line'),
                initialValue: lines.any((line) => line.id == _lineId)
                    ? _lineId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.line),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(l.reportSelectLine),
                  ),
                  for (final line in lines)
                    DropdownMenuItem(
                      value: line.id,
                      child: Text(
                        line.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy || !allowed
                    ? null
                    : (value) => setState(() {
                        _lineId = value;
                        _id = null;
                      }),
                validator: (value) =>
                    _kind == ReportKind.lineMissing && value == null
                    ? l.reportSelectLine
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('report.message'),
                controller: _text,
                enabled: allowed && !_busy,
                maxLength: 500,
                maxLines: 4,
                onChanged: (_) => _id = null,
                decoration: InputDecoration(labelText: l.message),
                validator: (text) =>
                    (text?.trim().length ?? 0) < 3 ? l.reportValidation : null,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                key: const ValueKey('report.send'),
                onPressed: allowed && !_busy ? _submit : null,
                child: Text(_busy ? l.communityLoading : l.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
