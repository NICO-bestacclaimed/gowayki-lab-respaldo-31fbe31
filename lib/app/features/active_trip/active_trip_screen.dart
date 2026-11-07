import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/planner/itinerary.dart';
import '../../../domain/tracking/trip_tracker.dart';
import '../../../shared/l10n/l10n.dart';
import '../../providers/active_trip_provider.dart';
import '../../providers/map_renderer_provider.dart';
import '../explorer/presentation/widgets/explorer_map.dart';

class ActiveTripScreen extends ConsumerWidget {
  const ActiveTripScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final active = ref.watch(activeTripProvider);
    if (active == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.activeTrip)),
        body: Center(child: Text(l.noActiveTrip)),
      );
    }
    final progress = active.progress;
    final leg = active.trip.legs[progress.legIndex];
    final message = switch (active.status) {
      ActiveTripStatus.completed => l.tripCompleted,
      ActiveTripStatus.stopped => l.tripStopped,
      ActiveTripStatus.error => l.tripTrackingFailed,
      _ => switch (progress.phase) {
        TripPhase.walking => l.activeWalk,
        TripPhase.waitingToBoard => l.activeBoard((leg as TransitLeg).lineName),
        TripPhase.riding => l.activeRide((leg as TransitLeg).lineName),
        TripPhase.completed => l.tripCompleted,
      },
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.activeTrip)),
      body: ListView(
        children: [
          SizedBox(
            height: 260,
            child: ref.watch(explorerMapRendererProvider)(
              ExplorerMap(
                position: active.stale || progress.offRoute
                    ? null
                    : progress.fix,
                showTransit: false,
                showStops: false,
                journeys: [active.trip],
                origin: active.trip.legs.first.from,
                destination: active.trip.legs.last.to,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${active.points.origin.name} → ${active.points.destination.name}',
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  key: const ValueKey('active.step'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (active.running) ...[
                  if (leg is TransitLeg)
                    Text(l.alightAt(leg.alightingStop.name)),
                  if (progress.remainingMeters != null &&
                      !progress.offRoute &&
                      !active.stale)
                    Text(
                      l.activeDistance(
                        progress.remainingMeters!.round().toString(),
                      ),
                      key: const ValueKey('active.distance'),
                    ),
                  if (progress.stopsRemaining != null &&
                      !progress.offRoute &&
                      !active.stale)
                    Text(l.remainingStops(progress.stopsRemaining!)),
                  if (active.stale || progress.offRoute)
                    Text(l.tripLocationUncertain),
                  if (active.notificationError) Text(l.tripAlertFailed),
                  const SizedBox(height: 12),
                  if (active.status == ActiveTripStatus.active)
                    FilledButton(
                      key: const ValueKey('active.confirm'),
                      onPressed: () =>
                          ref.read(activeTripProvider.notifier).confirmStep(),
                      child: Text(switch (progress.phase) {
                        TripPhase.waitingToBoard => l.confirmBoarded,
                        TripPhase.riding => l.confirmAlighted,
                        _ => l.confirmArrived,
                      }),
                    ),
                  Text(l.manualStepNote),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const ValueKey('active.finish'),
                  onPressed: () async {
                    try {
                      await ref.read(activeTripProvider.notifier).stop();
                      if (context.mounted) context.go('/explorar');
                    } on Object {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l.tripTrackingFailed)),
                        );
                      }
                    }
                  },
                  child: Text(l.endTrip),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
