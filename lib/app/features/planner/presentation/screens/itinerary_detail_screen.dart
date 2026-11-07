import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../domain/planner/itinerary.dart';
import '../../../../../domain/models/navigation_search.dart';
import '../../../../../shared/l10n/l10n.dart';
import '../../../../library/local_library.dart';
import '../../../../providers/map_renderer_provider.dart';
import '../../../../providers/sharing_providers.dart';
import '../../../../providers/start_trip_provider.dart';
import '../../../explorer/presentation/widgets/explorer_map.dart';
import '../widgets/itinerary_card.dart';
import '../widgets/journey_instructions.dart';

class ItineraryDetailScreen extends ConsumerStatefulWidget {
  const ItineraryDetailScreen({
    super.key,
    required this.trip,
    required this.points,
  });
  final Itinerary trip;
  final JourneyEndpoints points;
  @override
  ConsumerState<ItineraryDetailScreen> createState() => _ItineraryDetailState();
}

class _ItineraryDetailState extends ConsumerState<ItineraryDetailScreen> {
  final _mapKey = GlobalKey<ExplorerMapState>();
  final _scroll = ScrollController();
  bool _saving = false, _sharing = false, _starting = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _focus(GeoPoint point) async {
    try {
      await _mapKey.currentState?.flyTo(
        lat: point.latitude,
        lng: point.longitude,
      );
      if (mounted && _scroll.hasClients) {
        await _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } on Object {
      /* Native map can be reloading its style. */
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(localLibraryProvider.notifier)
          .toggle(LibraryItem.journey(widget.points));
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    final text = journeyShareText(widget.trip, widget.points, context.l10n);
    setState(() => _sharing = true);
    try {
      await ref.read(textSharingProvider).share(text, origin: origin);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _start(StartTripAction action) async {
    setState(() => _starting = true);
    try {
      await action(context, widget.trip, widget.points);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, trip = widget.trip;
    final library = ref.watch(localLibraryProvider);
    final start = ref.watch(startTripActionProvider);
    final saved =
        library.asData?.value.contains(LibraryItem.tripId(widget.points)) ??
        false;
    return Scaffold(
      appBar: AppBar(title: Text(l.details)),
      body: ListView(
        controller: _scroll,
        children: [
          SizedBox(
            height: 240,
            child: ref.watch(explorerMapRendererProvider)(
              ExplorerMap(
                key: _mapKey,
                showTransit: false,
                showStops: false,
                journeys: [trip],
                origin: GeoPoint(
                  widget.points.origin.latitude,
                  widget.points.origin.longitude,
                ),
                destination: GeoPoint(
                  widget.points.destination.latitude,
                  widget.points.destination.longitude,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${widget.points.origin.name} → ${widget.points.destination.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${l.minutesApprox(trip.durationMinutes.round())} · ${l.walkingMinutes(trip.walkingMinutes.round())} · ${l.fareAmount(trip.estimatedFare.toStringAsFixed(2))}',
            ),
          ),
          for (final (index, leg) in trip.legs.indexed)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  ListTile(
                    onTap: () => _focus(leg.from),
                    leading: leg is TransitLeg
                        ? LineAvatar(name: leg.lineName, color: leg.color)
                        : const Icon(Icons.directions_walk),
                    title: Text(
                      legInstructions(trip, index, widget.points, l).first,
                    ),
                    subtitle: Text(
                      legInstructions(
                        trip,
                        index,
                        widget.points,
                        l,
                      ).skip(1).join('\n'),
                    ),
                  ),
                  if (leg is TransitLeg && leg.intermediateStops.isNotEmpty)
                    ExpansionTile(
                      title: Text(l.intermediateStops),
                      children: [
                        for (final stop in leg.intermediateStops)
                          ListTile(
                            dense: true,
                            title: Text(stop.name),
                            subtitle: stop.needsReview
                                ? Text(l.estimatedName)
                                : null,
                            onTap: () => _focus(GeoPoint.stop(stop)),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.walkingEstimate),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (start != null) ...[
                  FilledButton.icon(
                    key: const ValueKey('trip.start'),
                    onPressed: _starting ? null : () => _start(start),
                    icon: const Icon(Icons.navigation),
                    label: Text(l.startTrip),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  key: const ValueKey('trip.save'),
                  onPressed: _saving || !library.hasValue ? null : _save,
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                  label: Text(saved ? l.removeSavedTrip : l.saveTrip),
                ),
                Text(l.savedTripNote),
                if (library.hasError) Text(l.saveFailed),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('trip.share'),
                  onPressed: _sharing ? null : _share,
                  icon: const Icon(Icons.share),
                  label: Text(l.share),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
