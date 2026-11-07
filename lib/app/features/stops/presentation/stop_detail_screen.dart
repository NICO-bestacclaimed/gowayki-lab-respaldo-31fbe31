import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/place_result.dart';
import '../../../../domain/models/navigation_search.dart';
import '../../../../domain/planner/itinerary.dart';
import '../../../../shared/l10n/l10n.dart';
import '../../../../shared/widgets/content_state.dart';
import '../../../library/local_library.dart';
import '../../../community/report_form.dart';
import '../../../community/report_widgets.dart';
import '../../../providers/location_providers.dart';
import '../../../providers/map_renderer_provider.dart';
import '../../../providers/planner_providers.dart';
import '../../../providers/transit_details_providers.dart';
import '../../explorer/presentation/widgets/explorer_map.dart';
import '../../planner/presentation/widgets/itinerary_card.dart';
import '../../search/presentation/search_screen.dart';

class StopDetailScreen extends ConsumerStatefulWidget {
  const StopDetailScreen({super.key, required this.stopId});
  final String stopId;
  @override
  ConsumerState<StopDetailScreen> createState() => _StopDetailState();
}

class _StopDetailState extends ConsumerState<StopDetailScreen> {
  final _mapKey = GlobalKey<ExplorerMapState>();
  Timer? _clock;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _favorite(PlaceResult point) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(localLibraryProvider.notifier)
          .toggle(
            LibraryItem(
              id: 'stop:${widget.stopId}',
              kind: LibraryKind.stop,
              label: point.name,
              point: point,
            ),
          );
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

  Future<void> _journey(PlaceResult point, {required bool origin}) async {
    final fix = ref.read(explorerLocationProvider).fix;
    final current = fix == null
        ? null
        : PlaceResult(
            id: 'current-location',
            name: context.l10n.myLocation,
            address: '',
            latitude: fix.point.latitude,
            longitude: fix.point.longitude,
          );
    final pair = await context.push<JourneyEndpoints>(
      '/buscar',
      extra: SearchArguments(
        origin: origin ? point : current,
        destination: origin ? null : point,
        currentLocation: current,
        editOrigin: !origin && current == null,
      ),
    );
    if (mounted && pair != null) await context.push('/planificar', extra: pair);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, library = ref.watch(localLibraryProvider);
    final saved =
        library.asData?.value.contains('stop:${widget.stopId}') ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l.stops)),
      body: ref
          .watch(stopDetailsProvider(widget.stopId))
          .when(
            loading: () => const ContentSkeleton(),
            error: (e, s) => ContentState(
              kind: ContentStateKind.error,
              onAction: () =>
                  ref.invalidate(stopDetailsProvider(widget.stopId)),
            ),
            data: (data) {
              final stop = data.entry.stop;
              final point = PlaceResult(
                id: stop.id,
                name: stop.name,
                address: '',
                latitude: stop.latitude,
                longitude: stop.longitude,
              );
              final headway = data.settings.frequencyAt(
                ref.read(appClockProvider)(),
              );
              return ListView(
                children: [
                  ListTile(
                    title: Text(
                      stop.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: stop.needsReview ? Text(l.estimatedName) : null,
                    trailing: IconButton(
                      key: const ValueKey('stopDetail.favorite'),
                      tooltip: saved ? l.removeFavorite : l.addFavorite,
                      onPressed: _saving || !library.hasValue
                          ? null
                          : () => _favorite(point),
                      icon: Icon(saved ? Icons.star : Icons.star_border),
                    ),
                  ),
                  SizedBox(
                    height: 240,
                    child: ref.watch(explorerMapRendererProvider)(
                      ExplorerMap(
                        key: _mapKey,
                        showTransit: false,
                        destination: GeoPoint.stop(stop),
                        onMapReady: () => _mapKey.currentState?.flyTo(
                          lat: stop.latitude,
                          lng: stop.longitude,
                          zoom: 17,
                        ),
                        onRouteTap: (route) => context.push(
                          '/linea/${Uri.encodeComponent(route.line.id)}',
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _journey(point, origin: false),
                          icon: const Icon(Icons.place),
                          label: Text(l.goHere),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _journey(point, origin: true),
                          icon: const Icon(Icons.trip_origin),
                          label: Text(l.leaveHere),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      key: const ValueKey('stopDetail.report'),
                      onPressed: () => openReportForm(
                        context,
                        point: point,
                        stopId: widget.stopId,
                      ),
                      icon: const Icon(Icons.report_outlined),
                      label: Text(l.reportProblem),
                    ),
                  ),
                  ReportsPanel(stopId: widget.stopId),
                  if (data.entry.services.isEmpty)
                    const ContentState(kind: ContentStateKind.empty),
                  for (final service in data.entry.services)
                    ListTile(
                      leading: LineAvatar(
                        name:
                            data.lines[service.lineId]?.shortName ??
                            service.lineId,
                        color: data.lines[service.lineId]?.color ?? '#B44910',
                      ),
                      title: Text(
                        data.lines[service.lineId]?.shortName ?? service.lineId,
                      ),
                      subtitle: Text(
                        '${service.direction == 'ida' ? l.outbound : l.inbound} · ${l.towards(service.headsign)}\n${headway == null ? l.noService : l.waitInstruction((headway / 2).round())}',
                      ),
                      onTap: () => context.push(
                        '/linea/${Uri.encodeComponent(service.lineId)}',
                      ),
                    ),
                ],
              );
            },
          ),
    );
  }
}
