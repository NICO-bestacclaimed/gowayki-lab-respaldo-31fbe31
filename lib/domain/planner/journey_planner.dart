import 'dart:isolate';

import 'itinerary.dart';
import 'itinerary_selection.dart';
import 'service_schedule.dart';
import 'planner_network.dart';
import 'raptor_planner.dart';
import 'reverse_raptor.dart';

enum JourneyTimeMode { leaveNow, leaveAt, arriveBy }

enum JourneyStatus { success, noService, noRoute }

class JourneyTime {
  const JourneyTime.now() : mode = JourneyTimeMode.leaveNow, at = null;
  JourneyTime.leaveAt(DateTime time)
    : mode = JourneyTimeMode.leaveAt,
      at = time.toUtc();
  JourneyTime.arriveBy(DateTime time)
    : mode = JourneyTimeMode.arriveBy,
      at = time.toUtc();
  final JourneyTimeMode mode;
  final DateTime? at;
}

class JourneyRequest {
  JourneyRequest({
    required this.origin,
    required this.destination,
    required this.time,
    this.maxBoardings = 3,
    this.order = JourneyOrder.fastest,
  }) {
    RangeError.checkValueInInterval(maxBoardings, 1, 3, 'maxBoardings');
  }
  final GeoPoint origin, destination;
  final JourneyTime time;
  final int maxBoardings;
  final JourneyOrder order;
}

class JourneyResponse {
  JourneyResponse({
    required this.status,
    required List<Itinerary> itineraries,
    required this.referenceTime,
    required this.accessRadiusMeters,
    this.walkingAlternative,
  }) : itineraries = List.unmodifiable(itineraries);
  final JourneyStatus status;
  final Itinerary? walkingAlternative;
  final List<Itinerary> itineraries;
  final DateTime referenceTime;
  final double accessRadiusMeters;
}

class JourneyPlanner {
  JourneyPlanner(this.network) : _forward = RaptorPlanner(network);
  final PlannerNetwork network;
  final RaptorPlanner _forward;

  JourneyResponse plan(JourneyRequest request, {DateTime? now}) {
    final result = _transport(request, now: now);
    final meters =
        request.origin.distanceTo(request.destination) *
        network.settings.walkDistanceFactor;
    Itinerary? walk;
    if (meters < 2500) {
      final duration = meters / network.settings.walkMetersPerMinute;
      final departure = request.time.mode == JourneyTimeMode.arriveBy
          ? addMinutes(result.referenceTime, -duration)
          : result.referenceTime;
      final arrival = addMinutes(departure, duration);
      walk = Itinerary(
        departureAt: departure,
        arrivalAt: arrival,
        legs: [
          WalkLeg(
            from: request.origin,
            to: request.destination,
            meters: meters,
            departureAt: departure,
            arrivalAt: arrival,
          ),
        ],
      );
    }
    return JourneyResponse(
      status: result.status,
      itineraries: selectItineraries(result.itineraries, request.order),
      referenceTime: result.referenceTime,
      accessRadiusMeters: result.accessRadiusMeters,
      walkingAlternative: walk,
    );
  }

  JourneyResponse _transport(JourneyRequest request, {DateTime? now}) {
    final reference = (request.time.at ?? now ?? DateTime.now()).toUtc();
    if (request.time.mode == JourneyTimeMode.arriveBy) {
      return _arriveBy(request, reference);
    }
    if (network.settings.frequencyAt(reference) == null) {
      return JourneyResponse(
        status: JourneyStatus.noService,
        itineraries: [],
        referenceTime: reference,
        accessRadiusMeters: network.settings.accessMeters,
      );
    }
    final result = _forward.plan(_query(request, reference));
    return JourneyResponse(
      status: result.itineraries.isEmpty
          ? JourneyStatus.noRoute
          : JourneyStatus.success,
      itineraries: result.itineraries,
      referenceTime: reference,
      accessRadiusMeters: result.accessRadiusMeters,
    );
  }

  JourneyResponse _arriveBy(JourneyRequest request, DateTime deadline) {
    for (final radius in {
      network.settings.accessMeters,
      network.settings.fallbackMeters,
    }) {
      final departure = latestDeparture(
        network,
        request.origin,
        request.destination,
        deadline,
        radius,
        request.maxBoardings,
      );
      if (departure == null) continue;
      var safe = DateTime.fromMicrosecondsSinceEpoch(
        departure.microsecondsSinceEpoch ~/ 1000000 * 1000000,
        isUtc: true,
      );
      for (var roundingAttempt = 0; roundingAttempt < 2; roundingAttempt++) {
        final forward = _forward.plan(
          _query(request, safe),
          accessRadiusMeters: radius,
        );
        final valid = forward.itineraries
            .where((trip) => !trip.arrivalAt.isAfter(deadline))
            .toList();
        if (valid.isNotEmpty) {
          return JourneyResponse(
            status: JourneyStatus.success,
            itineraries: valid,
            referenceTime: deadline,
            accessRadiusMeters: radius,
          );
        }
        safe = safe.subtract(const Duration(seconds: 1));
      }
    }
    return JourneyResponse(
      status: network.settings.frequencyAt(deadline) == null
          ? JourneyStatus.noService
          : JourneyStatus.noRoute,
      itineraries: [],
      referenceTime: deadline,
      accessRadiusMeters: network.settings.fallbackMeters,
    );
  }

  PlannerQuery _query(JourneyRequest request, DateTime departure) =>
      PlannerQuery(
        origin: request.origin,
        destination: request.destination,
        departureAt: departure,
        maxBoardings: request.maxBoardings,
      );
}

Future<JourneyResponse> planJourneyInIsolate(
  PlannerNetwork network,
  JourneyRequest request, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  return Isolate.run(() => JourneyPlanner(network).plan(request, now: clock));
}
