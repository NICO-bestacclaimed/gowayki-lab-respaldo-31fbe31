import 'dart:math' as math;
import '../planner/itinerary.dart';
import '../repositories/position_repository.dart';

enum TripPhase { walking, waitingToBoard, riding, completed }

enum TripAlertKind { alight, transfer }

class TripAlert {
  const TripAlert(this.kind, this.stopName);
  final TripAlertKind kind;
  final String stopName;
}

class TripProgress {
  const TripProgress({
    required this.legIndex,
    required this.phase,
    this.remainingMeters,
    this.stopsRemaining,
    this.fix,
    this.offRoute = false,
    this.alerts = const [],
  });
  final int legIndex;
  final TripPhase phase;
  final double? remainingMeters;
  final int? stopsRemaining;
  final PositionFix? fix;
  final bool offRoute;
  final List<TripAlert> alerts;
}

/// Local navigation aid. Boarding is explicit: walking past a route must not
/// arm its alighting alarm. Distances follow the selected vehicle geometry.
class TripTracker {
  TripTracker(this.trip) {
    if (trip.legs.isEmpty) throw ArgumentError('Empty trip');
    _phase = trip.legs.first is TransitLeg
        ? TripPhase.waitingToBoard
        : TripPhase.walking;
  }
  final Itinerary trip;
  int _index = 0;
  late TripPhase _phase;
  double _along = 0;
  DateTime? _lastAt;
  bool _warned = false;
  PositionFix? _fix;
  TripProgress get initial => TripProgress(legIndex: _index, phase: _phase);
  JourneyLeg get _leg => trip.legs[_index];

  TripProgress confirmStep() {
    if (_phase == TripPhase.waitingToBoard) {
      _phase = TripPhase.riding;
      _along = 0;
      _lastAt = null;
      _warned = false;
      return _snapshot();
    }
    if (_phase == TripPhase.completed) return _snapshot();
    final alerts = <TripAlert>[];
    _advance(alerts);
    return _snapshot(alerts: alerts);
  }

  void _advance(List<TripAlert> alerts) {
    if (_leg is TransitLeg &&
        trip.legs.skip(_index + 1).any((l) => l is TransitLeg)) {
      alerts.add(
        TripAlert(
          TripAlertKind.transfer,
          (_leg as TransitLeg).alightingStop.name,
        ),
      );
    }
    if (_index == trip.legs.length - 1) {
      _phase = TripPhase.completed;
    } else {
      _index++;
      _phase = _leg is TransitLeg
          ? TripPhase.waitingToBoard
          : TripPhase.walking;
    }
    _along = 0;
    _lastAt = null;
    _warned = false;
  }

  TripProgress _snapshot({
    double? remaining,
    int? stops,
    bool offRoute = false,
    List<TripAlert> alerts = const [],
  }) => TripProgress(
    legIndex: _index,
    phase: _phase,
    remainingMeters: remaining,
    stopsRemaining: stops,
    fix: _fix,
    offRoute: offRoute,
    alerts: List.unmodifiable(alerts),
  );

  TripProgress update(PositionFix fix, {required DateTime now}) {
    final age = now.difference(fix.at);
    if (_phase == TripPhase.completed ||
        !fix.accuracyMeters.isFinite ||
        fix.accuracyMeters < 0 ||
        fix.accuracyMeters > 60 ||
        age > const Duration(seconds: 30) ||
        age < const Duration(seconds: -5) ||
        (_lastAt != null && !fix.at.isAfter(_lastAt!))) {
      return _snapshot(offRoute: true);
    }
    _fix = fix;
    if (_phase == TripPhase.waitingToBoard) {
      _lastAt = fix.at;
      return _snapshot(remaining: fix.point.distanceTo(_leg.from));
    }
    final alerts = <TripAlert>[];
    if (_phase == TripPhase.walking) {
      _lastAt = fix.at;
      final distance = fix.point.distanceTo(_leg.to);
      if (distance <= 50) {
        _advance(alerts);
        return _snapshot(alerts: alerts);
      }
      return _snapshot(remaining: distance);
    }
    final leg = _leg as TransitLeg;
    final path = _Path(
      leg.geometry.length >= 2 ? leg.geometry : [leg.from, leg.to],
    );
    final elapsed = _lastAt == null
        ? 0
        : fix.at.difference(_lastAt!).inMilliseconds / 1000;
    final advance = _lastAt == null ? 250.0 : math.max(150.0, elapsed * 35);
    final projection = path.project(
      fix.point,
      min: math.max(0, _along - 50),
      max: _along + advance,
    );
    if (projection.offset > 100) return _snapshot(offRoute: true);
    _lastAt = fix.at;
    _along = math.max(_along, projection.along);
    final remaining = math.max(0.0, path.length - _along);
    // Locate stops monotonically on this leg, avoiding later crossings of a loop.
    var stopAlong = 0.0;
    var stopsRemaining = 1;
    for (final stop in leg.intermediateStops) {
      final p = path.project(GeoPoint.stop(stop), min: stopAlong);
      stopAlong = p.along;
      if (stopAlong > _along + 40) stopsRemaining++;
    }
    if (!_warned &&
        _along >= math.min(80, path.length * .1) &&
        (remaining <= 400 || stopsRemaining == 1)) {
      _warned = true;
      alerts.add(TripAlert(TripAlertKind.alight, leg.alightingStop.name));
    }
    if (remaining <= 60 && fix.point.distanceTo(leg.to) <= 60) {
      _advance(alerts);
      return _snapshot(alerts: alerts);
    }
    return _snapshot(
      remaining: remaining,
      stops: stopsRemaining,
      alerts: alerts,
    );
  }
}

class _Projection {
  const _Projection(this.along, this.offset);
  final double along, offset;
}

class _Path {
  _Path(this.points) {
    for (var i = 1; i < points.length; i++) {
      cumulative.add(cumulative.last + points[i - 1].distanceTo(points[i]));
    }
  }
  final List<GeoPoint> points;
  final cumulative = <double>[0];
  double get length => cumulative.last;
  _Projection project(
    GeoPoint point, {
    double min = 0,
    double max = double.infinity,
  }) {
    var best = const _Projection(0, double.infinity);
    const meters = 111195.08;
    final cosine = math.cos(point.latitude * math.pi / 180);
    for (var i = 1; i < points.length; i++) {
      final start = cumulative[i - 1], end = cumulative[i];
      if (end < min || start > max || end == start) continue;
      final a = points[i - 1], b = points[i];
      final ax = (a.longitude - point.longitude) * meters * cosine;
      final ay = (a.latitude - point.latitude) * meters;
      final dx = (b.longitude - a.longitude) * meters * cosine;
      final dy = (b.latitude - a.latitude) * meters;
      final fraction = (-(ax * dx + ay * dy) / (dx * dx + dy * dy)).clamp(
        ((min - start) / (end - start)).clamp(0.0, 1.0),
        ((max - start) / (end - start)).clamp(0.0, 1.0),
      );
      final offset = math.sqrt(
        math.pow(ax + fraction * dx, 2) + math.pow(ay + fraction * dy, 2),
      );
      if (offset < best.offset) {
        best = _Projection(start + fraction * (end - start), offset);
      }
    }
    return best;
  }
}
