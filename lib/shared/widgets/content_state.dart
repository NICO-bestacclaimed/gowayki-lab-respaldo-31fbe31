import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

enum ContentStateKind {
  empty,
  error,
  gpsOff,
  permission,
  noResults,
  outsideArea,
}

class ContentState extends StatelessWidget {
  const ContentState({
    super.key,
    required this.kind,
    this.message,
    this.onAction,
    this.actionLabel,
  });
  final ContentStateKind kind;
  final String? message, actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, title, body) = switch (kind) {
      ContentStateKind.empty => (Icons.inbox_outlined, l.emptyTitle, ''),
      ContentStateKind.error => (
        Icons.error_outline,
        l.errorTitle,
        l.errorBody,
      ),
      ContentStateKind.gpsOff => (
        Icons.location_disabled,
        l.gpsOffTitle,
        l.gpsOffBody,
      ),
      ContentStateKind.permission => (
        Icons.location_off_outlined,
        l.permissionTitle,
        l.permissionBody,
      ),
      ContentStateKind.noResults => (
        Icons.search_off,
        l.noResults,
        l.noResultsBody,
      ),
      ContentStateKind.outsideArea => (
        Icons.map_outlined,
        l.outsideTitle,
        l.outsideBody,
      ),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if ((message ?? body).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message ?? body, textAlign: TextAlign.center),
              ),
            if (onAction != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel ?? l.retry),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Static placeholders respect reduced motion and do not create endless tickers.
class ContentSkeleton extends StatelessWidget {
  const ContentSkeleton({super.key, this.rows = 4}) : assert(rows > 0);
  final int rows;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: rows,
      separatorBuilder: (context, i) => const SizedBox(height: 16),
      itemBuilder: (context, i) => Container(
        height: 68,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}
