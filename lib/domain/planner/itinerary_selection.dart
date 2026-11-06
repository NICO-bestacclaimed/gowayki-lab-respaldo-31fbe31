import 'itinerary.dart';

enum JourneyOrder { fastest, fewestTransfers, leastWalking }

String lineCombination(Itinerary trip) => trip.legs
    .whereType<TransitLeg>()
    .map((leg) => '${leg.lineId.length}:${leg.lineId}')
    .join();

bool itineraryDominates(Itinerary a, Itinerary b) =>
    a.durationMinutes <= b.durationMinutes + .000001 &&
    a.transfers <= b.transfers &&
    a.walkingMeters <= b.walkingMeters + .000001 &&
    (a.durationMinutes < b.durationMinutes - .000001 ||
        a.transfers < b.transfers ||
        a.walkingMeters < b.walkingMeters - .000001);

List<Itinerary> selectItineraries(
  Iterable<Itinerary> input,
  JourneyOrder order, {
  int limit = 5,
}) {
  RangeError.checkValueInInterval(limit, 1, 5, 'limit');
  final pareto = <Itinerary>[];
  for (final trip in input) {
    if (pareto.any((old) => itineraryDominates(old, trip))) continue;
    pareto.removeWhere((old) => itineraryDominates(trip, old));
    pareto.add(trip);
  }
  int compare(Itinerary a, Itinerary b) {
    final duration = a.durationMinutes.compareTo(b.durationMinutes);
    final transfers = a.transfers.compareTo(b.transfers);
    final walking = a.walkingMeters.compareTo(b.walkingMeters);
    final criteria = switch (order) {
      JourneyOrder.fastest => [duration, transfers, walking],
      JourneyOrder.fewestTransfers => [transfers, duration, walking],
      JourneyOrder.leastWalking => [walking, transfers, duration],
    };
    for (final comparison in criteria) {
      if (comparison != 0) return comparison;
    }
    return lineCombination(a).compareTo(lineCombination(b));
  }

  pareto.sort(compare);
  final seen = <String>{};
  return List.unmodifiable(
    pareto.where((trip) => seen.add(lineCombination(trip))).take(limit),
  );
}
