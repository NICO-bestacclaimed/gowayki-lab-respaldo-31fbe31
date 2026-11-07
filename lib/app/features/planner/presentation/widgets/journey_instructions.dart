import '../../../../../domain/planner/itinerary.dart';
import '../../../../../domain/models/navigation_search.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../../shared/format/journey_format.dart';

String walkDestination(Itinerary trip, int index, JourneyEndpoints points) {
  if (index + 1 < trip.legs.length && trip.legs[index + 1] is TransitLeg) {
    return (trip.legs[index + 1] as TransitLeg).boardingStop.name;
  }
  return points.destination.name;
}

List<String> legInstructions(
  Itinerary trip,
  int index,
  JourneyEndpoints points,
  AppLocalizations l,
) {
  final leg = trip.legs[index];
  if (leg is WalkLeg) {
    return [
      l.walkInstruction(
        leg.meters.round(),
        leg.durationMinutes.round(),
        walkDestination(trip, index, points),
      ),
    ];
  }
  final bus = leg as TransitLeg;
  return [
    l.boardInstruction(bus.lineName, bus.headsign),
    l.frequencyApprox((bus.expectedWaitMinutes * 2).round()),
    l.waitInstruction(bus.expectedWaitMinutes.round()),
    if (bus.waitingForBandMinutes > .01)
      l.bandHoldInstruction(bus.waitingForBandMinutes.round()),
    l.rideInstruction(
      bus.stopCount,
      bus.vehicleMinutes.round(),
      bus.alightingStop.name,
    ),
  ];
}

String journeyShareText(
  Itinerary trip,
  JourneyEndpoints points,
  AppLocalizations l,
) => [
  'GoWayki · ${points.origin.name} → ${points.destination.name}',
  l.estimatedTimes,
  '~${cityDateTime(trip.departureAt)} → ~${cityDateTime(trip.arrivalAt)} · ${l.minutesApprox(trip.durationMinutes.round())}',
  l.walkingMinutes(trip.walkingMinutes.round()),
  l.transferNumber(trip.transfers),
  l.fareAmount(trip.estimatedFare.toStringAsFixed(2)),
  for (var i = 0; i < trip.legs.length; i++)
    ...legInstructions(trip, i, points, l),
  l.walkingEstimate,
].join('\n');
