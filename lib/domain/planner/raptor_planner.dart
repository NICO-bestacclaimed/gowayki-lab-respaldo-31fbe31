import 'dart:isolate';
import 'dart:math' as math;

import 'itinerary.dart';
import 'destination_bounds.dart';
import 'planner_network.dart';
import 'service_schedule.dart';

class PlannerQuery {
  PlannerQuery({
    required this.origin,
    required this.destination,
    required DateTime departureAt,
    this.maxBoardings = 3,
  }) : departureAt = departureAt.toUtc() {
    RangeError.checkValueInInterval(maxBoardings, 1, 3, 'maxBoardings');
  }
  final GeoPoint origin, destination;
  final DateTime departureAt;
  final int maxBoardings;
}

class PlannerResult {
  PlannerResult({
    required List<Itinerary> itineraries,
    required this.accessRadiusMeters,
  }) : itineraries = List.unmodifiable(itineraries);

  /// Nondominated transport candidates before combination selection.
  final List<Itinerary> itineraries;
  final double accessRadiusMeters;
}

/// Multi-label round scanning: arrival, walking and number of boardings.
/// The boarding envelope and piecewise speeds preserve FIFO time dominance.
class RaptorPlanner {
  RaptorPlanner(
    this.network, {
    this.diagnostics,
    this.useDestinationBounds = true,
  });
  final bool useDestinationBounds;
  final Map<String, Object?>? diagnostics;
  final PlannerNetwork network;
  PlannerSettings get settings => network.settings;

  PlannerResult plan(PlannerQuery query, {double? accessRadiusMeters}) {
    if (accessRadiusMeters != null) return _search(query, accessRadiusMeters);
    var result = _search(query, settings.accessMeters);
    if (result.itineraries.isEmpty &&
        settings.fallbackMeters > settings.accessMeters) {
      result = _search(query, settings.fallbackMeters);
    }
    return result;
  }

  PlannerResult _search(PlannerQuery query, double radius) {
    final watch = diagnostics == null ? null : (Stopwatch()..start());
    final profiles = <Map<String, Object?>>[];
    final access = <String, List<_Label>>{};
    final egress = <String, double>{};
    for (final stop in network.stops.values) {
      final point = GeoPoint.stop(stop);
      final exit =
          point.distanceTo(query.destination) * settings.walkDistanceFactor;
      if (exit <= radius + 1e-7) egress[stop.id] = exit;
      if (!network.stopPatterns.containsKey(stop.id)) continue;
      final entry =
          query.origin.distanceTo(point) * settings.walkDistanceFactor;
      if (entry <= radius + 1e-7) {
        final arrival = addMinutes(
          query.departureAt,
          entry / settings.walkMetersPerMinute,
        );
        _relax(
          access,
          _Label(
            stop.id,
            arrival,
            null,
            _WalkStep(
              WalkLeg(
                from: query.origin,
                to: point,
                meters: entry,
                departureAt: query.departureAt,
                arrivalAt: arrival,
              ),
            ),
          ),
        );
      }
    }
    diagnostics?['access_us'] = watch?.elapsedMicroseconds;
    var previous = access;
    final global = <String, List<_Label>>{
      for (final entry in access.entries) entry.key: List.of(entry.value),
    };
    final finished = <_Finished>[];
    final bounds = useDestinationBounds
        ? DestinationBounds(network, egress, query.maxBoardings)
        : null;
    bool prune(DateTime time, double walk, int boards, OptimisticCost? cost) {
      if (cost == null) return false;
      if (!cost.$1.isFinite || !cost.$2.isFinite) return true;
      final arrival = addMinutes(
        time,
        cost.$1,
      ).subtract(const Duration(milliseconds: 10));
      return finished.any(
        (old) => _dominates(
          old.arrival,
          old.walking,
          old.label.boardings,
          arrival,
          walk + cost.$2,
          boards,
        ),
      );
    }

    bool pruneLabel(_Label label) => prune(
      label.arrival,
      label.walking,
      label.boardings,
      bounds?.at(label.stopId, query.maxBoardings - label.boardings),
    );
    bool pruneOnboard(_Onboard state, PlannerPattern pattern, int position) =>
        prune(
          state.time,
          state.previous.walking,
          state.previous.boardings + 1,
          bounds?.onboard(
            pattern,
            position,
            query.maxBoardings - state.previous.boardings - 1,
          ),
        );
    void finish(_Label label) {
      final meters = egress[label.stopId];
      if (meters == null) return;
      final candidate = _Finished(
        label,
        meters,
        addMinutes(label.arrival, meters / settings.walkMetersPerMinute),
      );
      if (finished.any(
        (old) =>
            _finishedDominates(old, candidate) ||
            _finishedEqual(old, candidate),
      )) {
        return;
      }
      finished.removeWhere((old) => _finishedDominates(candidate, old));
      finished.add(candidate);
    }

    for (
      var round = 1;
      round <= query.maxBoardings && previous.isNotEmpty;
      round++
    ) {
      watch?.reset();
      final marked = <int, int>{};
      var maxOnboard = 0;
      for (final stop in previous.keys) {
        for (final (pattern, position)
            in network.stopPatterns[stop] ?? const <(int, int)>[]) {
          marked.update(
            pattern,
            (old) => math.min(old, position),
            ifAbsent: () => position,
          );
        }
      }
      final boardingEstimates = <_Label, BoardingEstimate?>{};
      for (final entry in previous.entries) {
        if (!network.stopPatterns.containsKey(entry.key)) continue;
        for (final label in entry.value) {
          if (global[entry.key]?.contains(label) ?? false) {
            boardingEstimates[label] = settings.boarding(label.arrival);
          }
        }
      }
      final rides = <String, List<_Label>>{};
      for (final entry in marked.entries) {
        final pattern = network.patterns[entry.key];
        var onboard = <_Onboard>[];
        for (
          var position = entry.value;
          position < pattern.visits.length;
          position++
        ) {
          final visit = pattern.visits[position];
          final advanced = <_Onboard>[];
          for (final state in onboard) {
            final arrival = settings.travel(
              state.time,
              visit.distanceMeters -
                  pattern.visits[position - 1].distanceMeters,
            );
            if (arrival == null) continue;
            state.time = arrival;
            if (!pruneOnboard(state, pattern, position)) {
              _insertOnboard(advanced, state);
            }
          }
          onboard = advanced;
          if (diagnostics != null) {
            maxOnboard = math.max(maxOnboard, onboard.length);
          }
          for (final state in onboard) {
            final label = _Label(
              visit.stopId,
              state.time,
              state.previous,
              _RideStep(
                pattern,
                state.boardPosition,
                position,
                state.boardingAt,
                state.expectedWaitMinutes,
                state.time,
              ),
            );
            if (!pruneLabel(label) && _relax(rides, label, global: global)) {
              finish(label);
            }
          }
          // A boarding may only use the previous round, never an in-round arrival.
          for (final label in previous[visit.stopId] ?? const <_Label>[]) {
            final estimate = boardingEstimates[label];
            if (estimate != null) {
              final state = _Onboard(label, position, estimate, pattern.lineId);
              if (!pruneOnboard(state, pattern, position)) {
                _insertOnboard(onboard, state);
              }
            }
          }
        }
      }
      final scanUs = watch?.elapsedMicroseconds;
      watch?.reset();
      final next = <String, List<_Label>>{
        for (final entry in rides.entries) entry.key: List.of(entry.value),
      };
      // One explicit footpath between vehicles, without unbounded walking chains.
      for (final labels in rides.values) {
        for (final label in labels) {
          if (!(global[label.stopId]?.contains(label) ?? false)) continue;
          for (final edge in network.transfers[label.stopId] ?? const []) {
            final arrival = addMinutes(
              label.arrival,
              edge.walkMeters / settings.walkMetersPerMinute,
            );
            final candidate = _Label(
              edge.toStopId,
              arrival,
              label,
              _WalkStep(
                WalkLeg(
                  from: GeoPoint.stop(network.stops[label.stopId]!),
                  to: GeoPoint.stop(network.stops[edge.toStopId]!),
                  meters: edge.walkMeters,
                  departureAt: label.arrival,
                  arrivalAt: arrival,
                ),
              ),
            );
            if (!pruneLabel(candidate) &&
                _relax(next, candidate, global: global)) {
              finish(candidate);
            }
          }
        }
      }
      final walkUs = watch?.elapsedMicroseconds;
      watch?.reset();
      for (final labels in next.values) {
        for (final label in labels) {
          finish(label);
        }
      }
      if (diagnostics != null) {
        profiles.add({
          'round': round,
          'marked': marked.length,
          'previous_labels': previous.values.fold<int>(
            0,
            (sum, x) => sum + x.length,
          ),
          'rides': rides.values.fold<int>(0, (sum, x) => sum + x.length),
          'next_labels': next.values.fold<int>(0, (sum, x) => sum + x.length),
          'global_labels': global.values.fold<int>(
            0,
            (sum, x) => sum + x.length,
          ),
          'unique_scores': global.values.fold<int>(
            0,
            (sum, x) =>
                sum +
                x
                    .map(
                      (label) =>
                          '${label.arrival.microsecondsSinceEpoch}:${(label.walking * 1000000).round()}:${label.boardings}',
                    )
                    .toSet()
                    .length,
          ),
          'max_unique_scores': global.values.fold<int>(
            0,
            (sum, x) => math.max(
              sum,
              x
                  .map(
                    (label) =>
                        '${label.arrival.microsecondsSinceEpoch}:${(label.walking * 1000000).round()}:${label.boardings}',
                  )
                  .toSet()
                  .length,
            ),
          ),
          'max_global_frontier': global.values.fold<int>(
            0,
            (sum, x) => math.max(sum, x.length),
          ),
          'max_onboard': maxOnboard,
          'scan_us': scanUs,
          'walking_us': walkUs,
          'finish_us': watch?.elapsedMicroseconds,
          'finished_candidates': finished.length,
        });
      }
      previous = next;
    }
    finished.sort((a, b) => a.arrival.compareTo(b.arrival));
    final trips = <Itinerary>[];
    for (final destination in finished) {
      final reversed = <JourneyLeg>[];
      for (
        _Label? label = destination.label;
        label != null;
        label = label.previous
      ) {
        reversed.add(label.step.leg(network, label.previous));
      }
      final legs = reversed.reversed.toList()
        ..add(
          WalkLeg(
            from: GeoPoint.stop(network.stops[destination.label.stopId]!),
            to: query.destination,
            meters: destination.exitMeters,
            departureAt: destination.label.arrival,
            arrivalAt: destination.arrival,
          ),
        );
      trips.add(
        Itinerary(
          departureAt: query.departureAt,
          arrivalAt: destination.arrival,
          legs: legs,
        ),
      );
    }
    diagnostics?['rounds'] = profiles;
    return PlannerResult(itineraries: trips, accessRadiusMeters: radius);
  }

  bool _relax(
    Map<String, List<_Label>> target,
    _Label candidate, {
    Map<String, List<_Label>>? global,
  }) {
    final frontier =
        global?[candidate.stopId] ??
        target[candidate.stopId] ??
        const <_Label>[];
    var equivalent = 0;
    for (final old in frontier) {
      if (_labelDominates(old, candidate) || _labelEqual(old, candidate)) {
        return false;
      }
      if (old.arrival == candidate.arrival &&
          old.boardings == candidate.boardings &&
          (old.walking - candidate.walking).abs() <= _epsilon &&
          ++equivalent >= 5) {
        return false;
      }
    }
    final labels = target.putIfAbsent(candidate.stopId, () => []);
    labels.removeWhere((old) => _labelDominates(candidate, old));
    labels.add(candidate);
    if (global != null) {
      final all = global.putIfAbsent(candidate.stopId, () => []);
      all.removeWhere((old) => _labelDominates(candidate, old));
      all.add(candidate);
    }
    return true;
  }
}

const _epsilon = .000001;
bool _dominates(
  DateTime aTime,
  double aWalk,
  int aBoards,
  DateTime bTime,
  double bWalk,
  int bBoards,
) =>
    !aTime.isAfter(bTime) &&
    aWalk <= bWalk + _epsilon &&
    aBoards <= bBoards &&
    (aTime.isBefore(bTime) || aWalk < bWalk - _epsilon || aBoards < bBoards);
bool _labelDominates(_Label a, _Label b) => _dominates(
  a.arrival,
  a.walking,
  a.boardings,
  b.arrival,
  b.walking,
  b.boardings,
);
bool _labelEqual(_Label a, _Label b) =>
    a.arrival == b.arrival &&
    (a.walking - b.walking).abs() <= _epsilon &&
    a.signature == b.signature;
bool _finishedDominates(_Finished a, _Finished b) => _dominates(
  a.arrival,
  a.walking,
  a.label.boardings,
  b.arrival,
  b.walking,
  b.label.boardings,
);
bool _finishedEqual(_Finished a, _Finished b) =>
    a.arrival == b.arrival &&
    (a.walking - b.walking).abs() <= _epsilon &&
    a.label.signature == b.label.signature;

void _insertOnboard(List<_Onboard> states, _Onboard candidate) {
  bool dominates(_Onboard a, _Onboard b) => _dominates(
    a.time,
    a.previous.walking,
    a.previous.boardings,
    b.time,
    b.previous.walking,
    b.previous.boardings,
  );
  var equivalent = 0;
  for (final old in states) {
    if (dominates(old, candidate) ||
        (old.time == candidate.time &&
            (old.previous.walking - candidate.previous.walking).abs() <=
                _epsilon &&
            old.signature == candidate.signature)) {
      return;
    }
    if (old.time == candidate.time &&
        old.previous.boardings == candidate.previous.boardings &&
        (old.previous.walking - candidate.previous.walking).abs() <= _epsilon &&
        ++equivalent >= 5) {
      return;
    }
  }
  states.removeWhere((old) => dominates(candidate, old));
  states.add(candidate);
}

Future<PlannerResult> planInIsolate(
  PlannerNetwork network,
  PlannerQuery query,
) => Isolate.run(() => RaptorPlanner(network).plan(query));

class _Finished {
  _Finished(this.label, this.exitMeters, this.arrival);
  final _Label label;
  final double exitMeters;
  final DateTime arrival;
  double get walking => label.walking + exitMeters;
}

class _Label {
  _Label(this.stopId, this.arrival, this.previous, this.step)
    : walking =
          (previous?.walking ?? 0) + (step is _WalkStep ? step.walk.meters : 0),
      boardings = (previous?.boardings ?? 0) + (step is _RideStep ? 1 : 0),
      signature =
          (previous?.signature ?? '') +
          (step is _RideStep
              ? '${step.pattern.lineId.length}:${step.pattern.lineId}'
              : '');
  final String stopId, signature;
  final DateTime arrival;
  final _Label? previous;
  final _Step step;
  final double walking;
  final int boardings;
}

class _Onboard {
  _Onboard(
    this.previous,
    this.boardPosition,
    BoardingEstimate estimate,
    String lineId,
  ) : boardingAt = estimate.at,
      expectedWaitMinutes = estimate.expectedWaitMinutes,
      time = estimate.at,
      signature = '${previous.signature}${lineId.length}:$lineId';
  final _Label previous;
  final int boardPosition;
  final DateTime boardingAt;
  final double expectedWaitMinutes;
  final String signature;
  DateTime time;
}

sealed class _Step {
  JourneyLeg leg(PlannerNetwork network, _Label? previous);
}

class _WalkStep extends _Step {
  _WalkStep(this.walk);
  final WalkLeg walk;
  @override
  JourneyLeg leg(PlannerNetwork network, _Label? previous) => walk;
}

class _RideStep extends _Step {
  _RideStep(
    this.pattern,
    this.board,
    this.alight,
    this.boardingAt,
    this.expectedWaitMinutes,
    this.arrivalAt,
  );
  final PlannerPattern pattern;
  final int board, alight;
  final DateTime boardingAt, arrivalAt;
  final double expectedWaitMinutes;
  @override
  JourneyLeg leg(PlannerNetwork network, _Label? previous) => TransitLeg(
    lineId: pattern.lineId,
    lineName: pattern.lineName,
    color: pattern.color,
    patternId: pattern.id,
    direction: pattern.direction,
    headsign: pattern.headsign,
    boardingStop: network.stops[pattern.visits[board].stopId]!,
    alightingStop: network.stops[pattern.visits[alight].stopId]!,
    intermediateStops: [
      for (var i = board + 1; i < alight; i++)
        network.stops[pattern.visits[i].stopId]!,
    ],
    boardingAt: boardingAt,
    expectedWaitMinutes: expectedWaitMinutes,
    fare: pattern.fare,
    geometry: pattern.shape.clip(
      pattern.visits[board].distanceMeters,
      pattern.visits[alight].distanceMeters,
    ),
    departureAt: previous!.arrival,
    arrivalAt: arrivalAt,
  );
}
