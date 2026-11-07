import 'package:flutter/material.dart';
import '../../../../../domain/planner/itinerary.dart';
import '../../../../../shared/format/journey_format.dart';
import '../../../../../shared/l10n/l10n.dart';

Color lineColor(String value) => Color(
  0xFF000000 |
      (int.tryParse(value.replaceFirst('#', ''), radix: 16) ?? 0xB44910),
);

class LineAvatar extends StatelessWidget {
  const LineAvatar({super.key, required this.name, required this.color});
  final String name, color;
  @override
  Widget build(BuildContext context) {
    final background = lineColor(color);
    return CircleAvatar(
      radius: 17,
      backgroundColor: background,
      foregroundColor: background.computeLuminance() > .5
          ? Colors.black
          : Colors.white,
      child: Text(
        name.length > 3 ? name.substring(0, 3) : name,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class ItineraryCard extends StatelessWidget {
  const ItineraryCard({
    super.key,
    required this.trip,
    required this.number,
    required this.onSelect,
    this.onDetails,
    this.selected = false,
    this.fastest = false,
    this.leastWalking = false,
  });
  final Itinerary trip;
  final int number;
  final bool selected, fastest, leastWalking;
  final VoidCallback onSelect;
  final VoidCallback? onDetails;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.boardings == 0 ? l.walkOnly : l.optionNumber(number),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(l.minutesApprox(trip.durationMinutes.round())),
                ],
              ),
              Text(
                '~${cityTime(trip.departureAt)} → ~${cityTime(trip.arrivalAt)}',
              ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 8,
                children: [
                  for (final (index, leg) in trip.legs.indexed) ...[
                    if (index > 0) const Icon(Icons.arrow_forward, size: 14),
                    if (leg is WalkLeg)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_walk, size: 18),
                          Text(l.minutesApprox(leg.durationMinutes.round())),
                        ],
                      )
                    else if (leg is TransitLeg)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LineAvatar(name: leg.lineName, color: leg.color),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              leg.lineName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(l.walkingMinutes(trip.walkingMinutes.round())),
                  Text(l.waitingMinutes(trip.waitingMinutes.round())),
                  Text(l.transferNumber(trip.transfers)),
                  Text(l.fareAmount(trip.estimatedFare.toStringAsFixed(2))),
                ],
              ),
              Wrap(
                spacing: 6,
                children: [
                  if (fastest && trip.boardings > 0)
                    Chip(label: Text(l.fastest)),
                  if (leastWalking && trip.boardings > 0)
                    Chip(label: Text(l.leastWalking)),
                  if (trip.transfers == 0 && trip.boardings > 0)
                    Chip(label: Text(l.noTransfers)),
                ],
              ),
              if (onDetails != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onDetails,
                    child: Text(l.details),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
