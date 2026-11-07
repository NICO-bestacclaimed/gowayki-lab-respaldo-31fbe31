import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/models/place_result.dart';
import '../../../../../core/models/transit_line.dart';
import '../../../../../domain/models/city_pack_models.dart';
import '../../../../../domain/models/navigation_search.dart';
import '../../../../../domain/planner/itinerary.dart';
import '../../../../../shared/l10n/l10n.dart';
import '../../../../../shared/widgets/content_state.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/location_providers.dart';
import '../../../../providers/map_providers.dart';
import '../../../../settings/app_settings.dart';
import '../../../search/presentation/search_screen.dart';
import '../../map/nearby_stops.dart';
import '../../map/transit_map_data.dart';
import '../widgets/combis_sheet.dart';
import '../widgets/explorer_map.dart';

/// Native renderer boundary; widget tests can exercise the surrounding UI.
final explorerMapRendererProvider = Provider<Widget Function(ExplorerMap)>(
  (ref) =>
      (map) => map,
);

class ExplorerScreen extends ConsumerStatefulWidget {
  const ExplorerScreen({super.key, required this.onOpenMenu});
  final VoidCallback onOpenMenu;
  @override
  ConsumerState<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends ConsumerState<ExplorerScreen>
    with WidgetsBindingObserver {
  final _mapKey = GlobalKey<ExplorerMapState>();
  late final ExplorerLocationController _locationController;
  bool _showTransit = true, _visible = false;
  double _extent = .26;
  PlaceResult? _origin, _destination;
  TransitLine? _focused;
  TransitDirectionKind? _direction;
  GeoPoint? _nearbyPosition;
  TransitMapData? _nearbySource;
  double? _nearbyLimit;
  List<NearbyStop> _nearbyCache = const [];
  @override
  void initState() {
    super.initState();
    _locationController = ref.read(explorerLocationProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_visible &&
            (WidgetsBinding.instance.lifecycleState == null ||
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.resumed)) {
          ref.read(explorerLocationProvider.notifier).start();
        } else {
          ref.read(explorerLocationProvider.notifier).stop();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible) {
      ref.read(explorerLocationProvider.notifier).start(refresh: true);
    } else {
      ref.read(explorerLocationProvider.notifier).stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationController.stop();
    super.dispose();
  }

  PlaceResult? _currentLocation() {
    final location = ref.read(explorerLocationProvider);
    final fix = location.fix;
    if (location.status != LocationStatus.ready || fix == null) return null;
    return PlaceResult(
      id: 'current-location',
      name: context.l10n.myLocation,
      address: '',
      latitude: fix.point.latitude,
      longitude: fix.point.longitude,
    );
  }

  Future<void> _search({
    PlaceResult? origin,
    PlaceResult? destination,
    bool editOrigin = false,
  }) async {
    final current = _currentLocation();
    final points = await context.push<JourneyEndpoints>(
      '/buscar',
      extra: SearchArguments(
        origin: origin ?? _origin ?? current,
        destination: destination ?? _destination,
        currentLocation: current,
        editOrigin: editOrigin,
      ),
    );
    if (!mounted || points == null) return;
    setState(() {
      _origin = points.origin;
      _destination = points.destination;
      _focused = null;
      _direction = null;
    });
    try {
      await _mapKey.currentState?.flyTo(
        lat: points.destination.latitude,
        lng: points.destination.longitude,
      );
    } on Object {
      /* Map may be reloading. */
    }
  }

  Future<void> _longPress(GeoPoint point) async {
    final selected = PlaceResult(
      id: 'map:${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
      name: context.l10n.selectedPoint,
      address:
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
      latitude: point.latitude,
      longitude: point.longitude,
    );
    await _pointActions(selected);
  }

  Future<void> _pointActions(PlaceResult point, {CityMapStop? stop}) async {
    final origin = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(point.name, style: Theme.of(context).textTheme.titleLarge),
              if (stop?.stop.needsReview ?? false)
                Text(context.l10n.estimatedName),
              if (stop != null) ...[
                const SizedBox(height: 8),
                Text(
                  stop.services
                      .map((s) => s.headsign)
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .join(' · '),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.place),
                label: Text(context.l10n.goHere),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.trip_origin),
                label: Text(context.l10n.leaveHere),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || origin == null) return;
    await _search(
      origin: origin ? point : null,
      destination: origin ? null : point,
      editOrigin: !origin && (_origin ?? _currentLocation()) == null,
    );
  }

  void _stop(CityMapStop stop) => _pointActions(
    PlaceResult(
      id: stop.stop.id,
      name: stop.stop.name,
      address: '',
      latitude: stop.stop.latitude,
      longitude: stop.stop.longitude,
    ),
    stop: stop,
  );
  void _route(MapRouteSelection route) => setState(() {
    _focused = route.line;
    _direction = route.direction.kind;
    _showTransit = true;
  });
  Future<void> _locate() async {
    final controller = ref.read(explorerLocationProvider.notifier);
    await controller.start(refresh: true);
    if (!mounted) return;
    final location = ref.read(explorerLocationProvider);
    if (location.status == LocationStatus.permission) {
      await context.push('/ubicacion');
      return;
    }
    if (location.status == LocationStatus.gpsOff) {
      await ref.read(positionRepositoryProvider).openServiceSettings();
      return;
    }
    final fix = location.fix;
    if (fix != null) {
      try {
        await _mapKey.currentState?.flyTo(
          lat: fix.point.latitude,
          lng: fix.point.longitude,
        );
      } on Object {
        /* Map may be reloading. */
      }
    }
  }

  List<Widget> _nearby(TransitMapData data, ExplorerLocation location) {
    final l = context.l10n;
    if (location.status == LocationStatus.loading ||
        location.status == LocationStatus.idle) {
      return [const LinearProgressIndicator()];
    }
    if (location.status == LocationStatus.permission) {
      return [
        ContentState(
          kind: ContentStateKind.permission,
          actionLabel: l.allowLocation,
          onAction: () => context.push('/ubicacion'),
        ),
      ];
    }
    if (location.status == LocationStatus.gpsOff) {
      return [
        ContentState(
          kind: ContentStateKind.gpsOff,
          actionLabel: l.openSettings,
          onAction: () =>
              ref.read(positionRepositoryProvider).openServiceSettings(),
        ),
      ];
    }
    final fix = location.fix;
    if (location.status == LocationStatus.error || fix == null) {
      return [
        ContentState(
          kind: ContentStateKind.error,
          onAction: () =>
              ref.read(explorerLocationProvider.notifier).start(refresh: true),
        ),
      ];
    }
    final settings = ref.watch(appSettingsProvider).asData?.value;
    final limit = settings?.maxAccessMeters?.toDouble() ?? 1500;
    if (_nearbyPosition != fix.point ||
        _nearbySource != data ||
        _nearbyLimit != limit) {
      _nearbyCache = nearbyStops(
        data.stops.values,
        fix.point,
        limitMeters: limit,
      );
      _nearbyPosition = fix.point;
      _nearbySource = data;
      _nearbyLimit = limit;
    }
    final stops = _nearbyCache;
    if (stops.isEmpty) {
      return [const ContentState(kind: ContentStateKind.noResults)];
    }
    final names = {for (final line in data.lines) line.id: line.shortName};
    return [
      for (final nearby in stops)
        ListTile(
          leading: const Icon(Icons.directions_bus_outlined),
          title: Text(nearby.entry.stop.name),
          subtitle: Text(
            '${l.approxWalk(nearby.walkMeters.round())} · ${nearby.entry.services.map((s) => names[s.lineId] ?? s.lineId).toSet().join(', ')}${nearby.entry.stop.needsReview ? '\n${l.estimatedName}' : ''}',
          ),
          onTap: () => _stop(nearby.entry),
        ),
    ];
  }

  Widget _sheet(
    ScrollController scroll,
    AsyncValue<TransitMapData> data,
    ExplorerLocation location,
  ) {
    final l = context.l10n;
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.all(10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (_focused != null) ...[
            ListTile(
              title: Text(_focused!.shortName),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _focused = null;
                  _direction = null;
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final d in _focused!.directions)
                    ChoiceChip(
                      label: Text(
                        '${d.kind == TransitDirectionKind.ida ? l.outbound : l.inbound}: ${d.headsign}',
                      ),
                      selected: _direction == d.kind,
                      onSelected: (_) => setState(
                        () => _direction = _direction == d.kind ? null : d.kind,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_origin != null || _destination != null)
            ListTile(
              leading: const Icon(Icons.route),
              title: Text(
                '${_origin?.name ?? l.origin} → ${_destination?.name ?? l.destination}',
              ),
              onTap: () => _search(),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _origin = null;
                  _destination = null;
                }),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              l.nearbyStops,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...data.when(
            loading: () => <Widget>[const LinearProgressIndicator()],
            error: (e, s) => <Widget>[
              ContentState(
                kind: ContentStateKind.error,
                onAction: () => ref.invalidate(transitMapDataProvider),
              ),
            ],
            data: (value) => _nearby(value, location),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final location = ref.watch(explorerLocationProvider);
    final data = ref.watch(transitMapDataProvider);
    final favorites = ref.watch(favoriteLineIdsProvider);
    final favoriteLines =
        data.asData?.value.lines
            .where((line) => favorites.contains(line.id))
            .take(8)
            .toList() ??
        [];
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ref.watch(explorerMapRendererProvider)(
              ExplorerMap(
                key: _mapKey,
                showTransit: _showTransit,
                focusedLineId: _focused?.id,
                focusedDirection: _direction,
                origin: _origin == null
                    ? null
                    : GeoPoint(_origin!.latitude, _origin!.longitude),
                destination: _destination == null
                    ? null
                    : GeoPoint(_destination!.latitude, _destination!.longitude),
                position: location.status == LocationStatus.ready
                    ? location.fix
                    : null,
                onRouteTap: _route,
                onStopTap: _stop,
                onLongPress: _longPress,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: widget.onOpenMenu,
                      icon: const Icon(Icons.menu),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SearchBar(
                        leading: const Icon(Icons.search),
                        hintText: l.whereTo,
                        onTap: () => _search(),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                if (favoriteLines.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final line in favoriteLines)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(line.shortName),
                              onPressed: () => setState(() {
                                _focused = line;
                                _direction = null;
                                _showTransit = true;
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: MediaQuery.sizeOf(context).height * _extent + 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'lines',
                  tooltip: l.buses,
                  onPressed: () => CombisSheet.open(
                    context,
                    onSelected: (line) => setState(() {
                      _focused = line;
                      _direction = null;
                      _showTransit = true;
                    }),
                  ),
                  child: const Icon(Icons.directions_bus),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'layers',
                  tooltip: _showTransit ? l.hideRoutes : l.showRoutes,
                  onPressed: () => setState(() {
                    _showTransit = !_showTransit;
                    _focused = null;
                    _direction = null;
                  }),
                  child: Icon(_showTransit ? Icons.layers : Icons.layers_clear),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'location',
                  tooltip: l.myLocation,
                  onPressed: _locate,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              if ((_extent - notification.extent).abs() > .002) {
                setState(() => _extent = notification.extent);
              }
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: .26,
              minChildSize: .16,
              maxChildSize: .70,
              snap: true,
              snapSizes: const [.16, .26, .70],
              builder: (context, controller) =>
                  _sheet(controller, data, location),
            ),
          ),
        ],
      ),
    );
  }
}
