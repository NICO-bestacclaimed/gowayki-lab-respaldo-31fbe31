import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/updates/city_update.dart';
import '../../shared/l10n/l10n.dart';
import '../../l10n/generated/app_localizations.dart';
import 'city_update_controller.dart';

String updateText(CityUpdateState state, AppLocalizations l) =>
    switch (state.phase) {
      UpdatePhase.checking => l.updateChecking,
      UpdatePhase.downloading => l.updateDownloading,
      UpdatePhase.applying => l.updateApplying,
      UpdatePhase.restoring => l.updateRestoring,
      UpdatePhase.current => l.updateCurrent(state.version!),
      UpdatePhase.complete => l.updateComplete(state.version!),
      UpdatePhase.failed => switch (state.problem) {
        UpdateProblem.activeTrip => l.updateTripRunning,
        UpdateProblem.incompatibleApp => l.updateNeedsApp,
        UpdateProblem.integrity ||
        UpdateProblem.conflict ||
        UpdateProblem.invalidMetadata => l.updateRejected,
        UpdateProblem.cancelled => l.updateCancelled,
        UpdateProblem.unavailable => l.updateUnavailable,
        _ => l.updateFailed,
      },
      UpdatePhase.idle => '',
    };

class UpdateOverlay extends ConsumerWidget {
  const UpdateOverlay({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cityUpdateProvider), l = context.l10n;
    return Stack(
      children: [
        child,
        if (state.busy) ...[
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.black54),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(updateText(state, l), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 240,
                          child: LinearProgressIndicator(
                            value: state.total > 0
                                ? state.received / state.total
                                : null,
                          ),
                        ),
                        if (state.cancellable)
                          TextButton(
                            onPressed: () =>
                                ref.read(cityUpdateProvider.notifier).cancel(),
                            child: Text(l.cancel),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ] else if (state.phase != UpdatePhase.idle)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: Text(updateText(state, l))),
                      IconButton(
                        onPressed: () =>
                            ref.read(cityUpdateProvider.notifier).clear(),
                        icon: Icon(Icons.close, semanticLabel: l.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
