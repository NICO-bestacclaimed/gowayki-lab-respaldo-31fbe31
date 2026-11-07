import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../domain/models/navigation_search.dart';
import '../../../../../domain/repositories/journey_planner_client.dart';
import '../../../../../domain/planner/itinerary.dart';
import '../../../../../domain/planner/itinerary_selection.dart';
import '../../../../../domain/planner/journey_planner.dart';
import '../../../../../domain/planner/service_schedule.dart';
import '../../../../../shared/format/journey_format.dart';
import '../../../../../shared/l10n/l10n.dart';
import '../../../../../shared/widgets/content_state.dart';
import '../../../../providers/map_renderer_provider.dart';
import '../../../../providers/planner_providers.dart';
import '../../../../settings/app_settings.dart';
import '../../../explorer/presentation/widgets/explorer_map.dart';
import '../widgets/itinerary_card.dart';
import 'itinerary_detail_screen.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key, required this.points});
  final JourneyEndpoints points;
  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late Future<JourneyResponse> _future;
  JourneyTime _time = const JourneyTime.now();
  JourneyOrder _order = JourneyOrder.fastest;
  int _selected = 0;
  @override
  void initState() {
    super.initState();
    _future = _compute();
  }

  @override
  void didUpdateWidget(covariant PlannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _reload();
  }

  Future<JourneyResponse> _compute() async {
    final client =
        ref.read(plannerClientProvider).asData?.value ??
        await ref.read<Future<JourneyPlannerClient>>(
          plannerClientProvider.future,
        );
    if (!mounted) throw StateError('Screen closed');
    final settings =
        ref.read(appSettingsProvider).asData?.value ??
        await ref.read<Future<AppSettings>>(appSettingsProvider.future);
    final origin = widget.points.origin,
        destination = widget.points.destination;
    return client.plan(
      JourneyRequest(
        origin: GeoPoint(origin.latitude, origin.longitude),
        destination: GeoPoint(destination.latitude, destination.longitude),
        time: _time,
        order: _order,
        maxBoardings: settings.maxBoardings,
      ),
      now: ref.read(appClockProvider)(),
    );
  }

  void _reload() => setState(() {
    _selected = 0;
    _future = _compute();
  });
  Future<void> _chooseTime(JourneyTimeMode? mode) async {
    if (mode == null) return;
    if (mode == JourneyTimeMode.leaveNow) {
      _time = const JourneyTime.now();
      _reload();
      return;
    }
    final now = ref.read(appClockProvider)(),
        cityNow = PlannerSettings.cityClock(now);
    final current = PlannerSettings.cityClock(_time.at ?? now);
    final first = DateTime(cityNow.year, cityNow.month, cityNow.day);
    final initial = DateTime(current.year, current.month, current.day);
    final day = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (!mounted || day == null) return;
    final clock = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (!mounted || clock == null) return;
    final instant = DateTime.utc(
      day.year,
      day.month,
      day.day,
      clock.hour + 5,
      clock.minute,
    );
    _time = mode == JourneyTimeMode.leaveAt
        ? JourneyTime.leaveAt(instant)
        : JourneyTime.arriveBy(instant);
    _reload();
  }

  Widget _controls() {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.points.origin.name} → ${widget.points.destination.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<JourneyTimeMode>(
            key: ValueKey('planner.time.${_time.mode.name}.${_time.at}'),
            initialValue: _time.mode,
            items: [
              DropdownMenuItem(
                value: JourneyTimeMode.leaveNow,
                child: Text(l.leaveNow),
              ),
              DropdownMenuItem(
                value: JourneyTimeMode.leaveAt,
                child: Text(l.leaveAt),
              ),
              DropdownMenuItem(
                value: JourneyTimeMode.arriveBy,
                child: Text(l.arriveBy),
              ),
            ],
            onChanged: _chooseTime,
          ),
          if (_time.at != null)
            TextButton(
              onPressed: () => _chooseTime(_time.mode),
              child: Text('~${cityDateTime(_time.at!)}'),
            ),
          const SizedBox(height: 8),
          DropdownButtonFormField<JourneyOrder>(
            key: const ValueKey('planner.order'),
            initialValue: _order,
            items: [
              DropdownMenuItem(
                value: JourneyOrder.fastest,
                child: Text(l.fastest),
              ),
              DropdownMenuItem(
                value: JourneyOrder.fewestTransfers,
                child: Text(l.fewestTransfers),
              ),
              DropdownMenuItem(
                value: JourneyOrder.leastWalking,
                child: Text(l.leastWalking),
              ),
            ],
            onChanged: (order) {
              if (order != null) {
                _order = order;
                _reload();
              }
            },
          ),
        ],
      ),
    );
  }

  List<Itinerary> _options(JourneyResponse response) => [
    ...response.itineraries,
    if (response.walkingAlternative != null) response.walkingAlternative!,
  ];
  Widget _results(AsyncSnapshot<JourneyResponse> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const SliverToBoxAdapter(
        child: SizedBox(height: 280, child: ContentSkeleton(rows: 3)),
      );
    }
    if (snapshot.hasError) {
      return SliverToBoxAdapter(
        child: ContentState(
          kind: ContentStateKind.error,
          onAction: () {
            ref.invalidate(plannerClientProvider);
            _reload();
          },
        ),
      );
    }
    final response = snapshot.requireData, options = _options(response);
    final fastest = response.itineraries
        .map((t) => t.durationMinutes)
        .fold<double>(double.infinity, math.min);
    final walking = response.itineraries
        .map((t) => t.walkingMeters)
        .fold<double>(double.infinity, math.min);
    return SliverList.list(
      children: [
        if (response.status == JourneyStatus.noService)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.noService),
          ),
        if (response.status == JourneyStatus.noRoute)
          const ContentState(kind: ContentStateKind.noResults),
        for (final (index, trip) in options.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ItineraryCard(
              key: ValueKey('itinerary.$index'),
              trip: trip,
              number: index + 1,
              selected: _selected == index,
              fastest: (trip.durationMinutes - fastest).abs() < .0001,
              leastWalking: (trip.walkingMeters - walking).abs() < .0001,
              onSelect: () => setState(() => _selected = index),
              onDetails: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      ItineraryDetailScreen(trip: trip, points: widget.points),
                ),
              ),
            ),
          ),
        if (response.walkingAlternative != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.walkingEstimate),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider, (previous, next) {
      final a = previous?.asData?.value, b = next.asData?.value;
      if (a != null &&
          b != null &&
          (a.maxAccessMeters != b.maxAccessMeters ||
              a.avoidTransfers != b.avoidTransfers)) {
        _reload();
      }
    });
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.planTrip)),
      body: FutureBuilder<JourneyResponse>(
        future: _future,
        builder: (context, snapshot) {
          final options =
              snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData
              ? _options(snapshot.requireData)
              : const <Itinerary>[];
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _controls()),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: (MediaQuery.sizeOf(context).height * .34).clamp(
                    160.0,
                    280.0,
                  ),
                  child: ref.watch(explorerMapRendererProvider)(
                    ExplorerMap(
                      showTransit: false,
                      showStops: false,
                      origin: GeoPoint(
                        widget.points.origin.latitude,
                        widget.points.origin.longitude,
                      ),
                      destination: GeoPoint(
                        widget.points.destination.latitude,
                        widget.points.destination.longitude,
                      ),
                      journeys: options,
                      selectedJourney: _selected,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(context.l10n.estimatedTimes),
                ),
              ),
              _results(snapshot),
            ],
          );
        },
      ),
    );
  }
}
