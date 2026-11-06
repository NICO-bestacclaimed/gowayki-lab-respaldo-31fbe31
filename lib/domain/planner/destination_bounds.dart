import 'dart:math' as math;
import 'planner_network.dart';

typedef OptimisticCost = (double, double); // minutes, walking meters
const _unreachable = (double.infinity, double.infinity);

/// Relaxed reverse rounds: maximum bus speed, zero waiting, at most N more
/// vehicles. Each component is independently optimistic, so pruning is safe.
class DestinationBounds {
  DestinationBounds(this.network, Map<String, double> egress, int rounds) {
    final rates = network.settings.speeds
        .map((b) => b.value)
        .whereType<double>();
    rate = rates.isEmpty
        ? network.settings.walkMetersPerMinute
        : rates.reduce(math.max) * 1000 / 60;
    var previous = <String, OptimisticCost>{
      for (final e in egress.entries)
        e.key: (e.value / network.settings.walkMetersPerMinute, e.value),
    };
    previous = _walking(previous, previous);
    levels.add(previous);
    for (var round = 1; round <= rounds; round++) {
      final rides = <String, OptimisticCost>{};
      for (final pattern in network.patterns) {
        var minutes = double.infinity, walk = double.infinity;
        for (var i = pattern.visits.length - 1; i >= 0; i--) {
          final visit = pattern.visits[i];
          if (i < pattern.visits.length - 1) {
            minutes +=
                (pattern.visits[i + 1].distanceMeters - visit.distanceMeters) /
                rate;
            _merge(rides, visit.stopId, minutes, walk);
          }
          final tail = previous[visit.stopId] ?? _unreachable;
          minutes = math.min(minutes, tail.$1);
          walk = math.min(walk, tail.$2);
        }
      }
      previous = _walking(rides, previous);
      levels.add(previous);
    }
  }
  final PlannerNetwork network;
  late final double rate;
  final levels = <Map<String, OptimisticCost>>[];
  final _suffixes = <(String, int), List<OptimisticCost>>{};

  Map<String, OptimisticCost> _walking(
    Map<String, OptimisticCost> source,
    Map<String, OptimisticCost> carry,
  ) {
    final target = Map<String, OptimisticCost>.of(carry);
    for (final e in source.entries) {
      _merge(target, e.key, e.value.$1, e.value.$2);
    }
    for (final entry in network.transfers.entries) {
      for (final edge in entry.value) {
        final tail = source[edge.toStopId];
        if (tail != null) {
          _merge(
            target,
            entry.key,
            tail.$1 + edge.walkMeters / network.settings.walkMetersPerMinute,
            tail.$2 + edge.walkMeters,
          );
        }
      }
    }
    return target;
  }

  OptimisticCost at(String stop, int remaining) =>
      levels[remaining][stop] ?? _unreachable;
  OptimisticCost onboard(PlannerPattern pattern, int position, int remaining) {
    final values = _suffixes.putIfAbsent((pattern.id, remaining), () {
      final result = List<OptimisticCost>.filled(
        pattern.visits.length,
        _unreachable,
      );
      var minutes = double.infinity, walk = double.infinity;
      for (var i = pattern.visits.length - 1; i >= 0; i--) {
        if (i < pattern.visits.length - 1) {
          minutes +=
              (pattern.visits[i + 1].distanceMeters -
                  pattern.visits[i].distanceMeters) /
              rate;
        }
        final tail = at(pattern.visits[i].stopId, remaining);
        minutes = math.min(minutes, tail.$1);
        walk = math.min(walk, tail.$2);
        result[i] = (minutes, walk);
      }
      return result;
    });
    return values[position];
  }
}

void _merge(
  Map<String, OptimisticCost> target,
  String stop,
  double minutes,
  double walk,
) {
  final previous = target[stop] ?? _unreachable;
  if (minutes < previous.$1 || walk < previous.$2) {
    target[stop] = (
      math.min(minutes, previous.$1),
      math.min(walk, previous.$2),
    );
  }
}
