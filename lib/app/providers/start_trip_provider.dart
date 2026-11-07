import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/navigation_search.dart';
import '../../domain/planner/itinerary.dart';
import '../../domain/repositories/location_permission_repository.dart';
import '../../shared/l10n/l10n.dart';
import 'active_trip_provider.dart';
import 'app_providers.dart';

typedef StartTripAction =
    Future<void> Function(
      BuildContext context,
      Itinerary trip,
      JourneyEndpoints points,
    );
final startTripActionProvider = Provider<StartTripAction?>((ref) {
  if (!ref.watch(tripTrackingRepositoryProvider).supported) return null;
  return (context, trip, points) async {
    final l = context.l10n;
    if (ref.read(activeTripProvider)?.running ?? false) {
      context.push('/viaje');
      return;
    }
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.startTrip),
        content: Text(l.tripPermissionDisclosure),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancelTripStart),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.continueAction),
          ),
        ],
      ),
    );
    if (agreed != true || !context.mounted || !ref.mounted) return;
    final permissions = ref.read(locationPermissionRepositoryProvider);
    var access = await permissions.check();
    if (access == LocationAccess.denied) access = await permissions.request();
    if (!context.mounted || !ref.mounted) return;
    if (access != LocationAccess.allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.tripPermissionRequired),
          action: SnackBarAction(
            label: l.settings,
            onPressed: () {
              permissions.openSettings();
            },
          ),
        ),
      );
      return;
    }
    final allowed = await ref
        .read(tripNotificationsProvider)
        .requestPermission();
    if (!context.mounted || !ref.mounted) return;
    if (!allowed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.tripNotificationsRequired)));
      return;
    }
    // Android location services must start while the activity is visible.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.tripStartVisible)));
      return;
    }
    await ref.read(activeTripProvider.notifier).start(trip, points, l);
    if (context.mounted) context.push('/viaje');
  };
});
