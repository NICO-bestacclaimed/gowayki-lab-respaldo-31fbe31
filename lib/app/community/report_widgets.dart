import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/community/community_report.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/l10n/l10n.dart';
import '../providers/app_providers.dart';
import 'community_providers.dart';

String reportKindText(ReportKind kind, AppLocalizations l) => switch (kind) {
  ReportKind.detour => l.reportDetour,
  ReportKind.missingStop => l.reportMissingStop,
  ReportKind.stopName => l.reportStopName,
  ReportKind.lineMissing => l.reportLineMissing,
  ReportKind.other => l.feedbackOther,
};
String communityError(Object error, AppLocalizations l) => switch (error) {
  CommunityException(code: CommunityFailure.needsAccount) =>
    l.reportNeedsAccount,
  CommunityException(code: CommunityFailure.expired) => l.reportExpired,
  _ => l.communityError,
};
Future<void> showCommunityReport(
  BuildContext context,
  CommunityReport report,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ReportCard(report: report),
    ),
  ),
);

class ReportCard extends ConsumerStatefulWidget {
  const ReportCard({super.key, required this.report});
  final CommunityReport report;
  @override
  ConsumerState<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<ReportCard> {
  bool _busy = false, _confirmed = false;
  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final created = await ref
          .read(reportsRepositoryProvider)
          .confirm(widget.report.id);
      if (!mounted) return;
      setState(() => _confirmed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created
                ? context.l10n.reportConfirmed
                : context.l10n.reportAlreadyConfirmed,
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(communityError(error, context.l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n,
        report = widget.report,
        user = ref.watch(authStateProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          reportKindText(report.kind, l),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(report.description),
        const SizedBox(height: 8),
        Text('${l.communityReports} · ${report.confirmations} 👍'),
        Text(l.reportLifetime),
        if (ref.watch(useFirebaseProvider) && user != null && !user.isAnonymous)
          OutlinedButton.icon(
            onPressed: _busy || _confirmed ? null : _confirm,
            icon: const Icon(Icons.thumb_up_outlined),
            label: Text(
              _confirmed ? l.reportAlreadyConfirmed : l.reportConfirm,
            ),
          )
        else if (ref.watch(useFirebaseProvider))
          TextButton(
            onPressed: () => context.push('/acceso'),
            child: Text(l.reportNeedsAccount),
          ),
      ],
    );
  }
}

class ReportsPanel extends ConsumerWidget {
  const ReportsPanel({super.key, this.stopId, this.lineId, this.stopIds});
  final String? stopId, lineId;
  final Set<String>? stopIds;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(useFirebaseProvider)) return const SizedBox.shrink();
    final reports = ref.watch(activeReportsProvider),
        raw = ref.watch(reportsRawProvider),
        l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.communityReports,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (raw.asData?.value.fromCache ?? false) Text(l.communityCached),
          ...reports.when(
            loading: () => [Text(l.communityLoading)],
            error: (_, s) => [
              Text(l.communityUnavailable),
              TextButton(
                onPressed: () => ref.invalidate(reportsRawProvider),
                child: Text(l.retry),
              ),
            ],
            data: (rows) {
              final matching = rows
                  .where(
                    (r) =>
                        (stopId == null || r.stopId == stopId) &&
                        (lineId == null ||
                            r.lineId == lineId ||
                            (r.stopId != null &&
                                (stopIds?.contains(r.stopId) ?? false))),
                  )
                  .toList();
              if (matching.isEmpty) {
                return [
                  Text(
                    (raw.asData?.value.fromCache ?? false)
                        ? l.communityUnavailable
                        : l.reportNone,
                  ),
                ];
              }
              return [
                for (final report in matching)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.report_outlined),
                    title: Text(reportKindText(report.kind, l)),
                    subtitle: Text(
                      report.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text('${report.confirmations} 👍'),
                    onTap: () => showCommunityReport(context, report),
                  ),
              ];
            },
          ),
        ],
      ),
    );
  }
}
