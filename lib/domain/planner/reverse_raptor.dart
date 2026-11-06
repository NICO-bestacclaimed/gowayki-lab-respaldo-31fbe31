import 'dart:math' as math;

import 'itinerary.dart';
import 'planner_network.dart';
import 'service_schedule.dart';

/// Latest feasible departure. The normal forward engine reconstructs and
/// validates the actual itinerary afterwards, including microsecond rounding.
DateTime? latestDeparture(
  PlannerNetwork network,
  GeoPoint origin,
  GeoPoint destination,
  DateTime deadline,
  double radius,
  int maxBoardings,
) {
  final settings = network.settings;
  final access = <String, double>{};
  final egress = <String, double>{};
  for (final stop in network.stops.values) {
    final point = GeoPoint.stop(stop);
    final entry = origin.distanceTo(point) * settings.walkDistanceFactor;
    final exit = point.distanceTo(destination) * settings.walkDistanceFactor;
    if (entry <= radius + 1e-7) access[stop.id] = entry;
    if (exit <= radius + 1e-7) egress[stop.id] = exit;
  }
  final incoming = network.incomingTransfers;
  DateTime? best;
  for (final (opening, closing) in settings.serviceWindows(deadline).reversed) {
    if (best != null && !closing.isAfter(best)) break;
    var previous = <String, DateTime>{};
    for (final entry in egress.entries) {
      final alight = addMinutes(
        deadline,
        -entry.value / settings.walkMetersPerMinute,
      );
      if (!alight.isBefore(opening)) {
        previous[entry.key] = alight.isAfter(closing) ? closing : alight;
      }
    }
    for (var round = 1; round <= maxBoardings && previous.isNotEmpty; round++) {
      final marked = <int, int>{};
      for (final id in previous.keys) {
        for (final (pattern, index)
            in network.stopPatterns[id] ?? const <(int, int)>[]) {
          marked.update(
            pattern,
            (old) => math.max(old, index),
            ifAbsent: () => index,
          );
        }
      }
      final rides = <String, DateTime>{};
      for (final entry in marked.entries) {
        final pattern = network.patterns[entry.key];
        DateTime? onboard;
        for (var index = entry.value; index >= 0; index--) {
          final visit = pattern.visits[index];
          if (onboard != null) {
            onboard = settings.travelBackwards(
              onboard,
              pattern.visits[index + 1].distanceMeters - visit.distanceMeters,
            );
            if (onboard != null) {
              final ready = settings.readyBefore(onboard, opening);
              if (ready != null) _latest(rides, visit.stopId, ready);
            }
          }
          final alight = previous[visit.stopId];
          if (alight != null && (onboard == null || alight.isAfter(onboard))) {
            onboard = alight;
          }
        }
      }
      final next = Map<String, DateTime>.of(rides);
      for (final entry in rides.entries) {
        for (final (from, meters)
            in incoming[entry.key] ?? const <(String, double)>[]) {
          final ready = addMinutes(
            entry.value,
            -meters / settings.walkMetersPerMinute,
          );
          if (!ready.isBefore(opening)) _latest(next, from, ready);
        }
      }
      for (final entry in next.entries) {
        final meters = access[entry.key];
        if (meters == null) continue;
        final departure = addMinutes(
          entry.value,
          -meters / settings.walkMetersPerMinute,
        );
        if (!departure.isBefore(opening) &&
            (best == null || departure.isAfter(best))) {
          best = departure;
        }
      }
      previous = next;
    }
  }
  return best;
}

void _latest(Map<String, DateTime> labels, String id, DateTime time) {
  if (labels[id] == null || time.isAfter(labels[id]!)) labels[id] = time;
}
