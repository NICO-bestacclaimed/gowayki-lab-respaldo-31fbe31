import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../../../core/models/transit_line.dart';
import '../../../../../domain/models/city_pack_models.dart';
import '../../../../../domain/repositories/position_repository.dart';
import '../../../../../domain/planner/itinerary.dart';
import '../../../../../infra/map/offline_map_package.dart';
import '../../../../../shared/l10n/l10n.dart';
import '../../../../../shared/widgets/content_state.dart';
import '../../../../providers/map_providers.dart';
import '../../map/transit_map_data.dart';

class ExplorerMap extends ConsumerStatefulWidget {
  const ExplorerMap({
    super.key,
    this.showTransit = true,
    this.showStops = true,
    this.journeys = const [],
    this.selectedJourney = 0,
    this.focusedLineId,
    this.focusedDirection,
    this.position,
    this.origin,
    this.destination,
    this.onMapReady,
    this.onRouteTap,
    this.onStopTap,
    this.onLongPress,
  });
  final bool showTransit, showStops;
  final List<Itinerary> journeys;
  final int selectedJourney;
  final String? focusedLineId;
  final TransitDirectionKind? focusedDirection;
  final GeoPoint? origin, destination;
  final PositionFix? position;
  final VoidCallback? onMapReady;
  final ValueChanged<MapRouteSelection>? onRouteTap;
  final ValueChanged<CityMapStop>? onStopTap;
  final ValueChanged<GeoPoint>? onLongPress;
  @override
  ConsumerState<ExplorerMap> createState() => ExplorerMapState();
}

class ExplorerMapState extends ConsumerState<ExplorerMap> {
  String? _style;
  Object? _error;
  MapLibreMapController? _map;
  TransitMapData? _data;
  Brightness? _brightness;
  bool _ready = false;
  int _generation = 0;
  Future<void>? _drawing;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_brightness != brightness) {
      _brightness = brightness;
      _boot();
    }
  }

  @override
  void didUpdateWidget(covariant ExplorerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _position());
    }
    if (oldWidget.showTransit != widget.showTransit ||
        oldWidget.showStops != widget.showStops ||
        oldWidget.journeys != widget.journeys ||
        oldWidget.selectedJourney != widget.selectedJourney ||
        oldWidget.focusedLineId != widget.focusedLineId ||
        oldWidget.focusedDirection != widget.focusedDirection ||
        !_samePoint(oldWidget.origin, widget.origin) ||
        !_samePoint(oldWidget.destination, widget.destination)) {
      _redraw();
      if (oldWidget.journeys != widget.journeys) _fitJourneys();
      if (oldWidget.focusedLineId != widget.focusedLineId ||
          oldWidget.focusedDirection != widget.focusedDirection) {
        _fitFocusedLine();
      }
    }
  }

  bool _samePoint(GeoPoint? a, GeoPoint? b) =>
      a?.latitude == b?.latitude && a?.longitude == b?.longitude;
  Future<void> _position() async {
    final map = _map, fix = widget.position;
    if (!mounted || !_ready || map == null || fix == null) return;
    try {
      await map.updateManualLocation(
        ManualLocationUpdate(
          target: LatLng(fix.point.latitude, fix.point.longitude),
          horizontalAccuracy: fix.accuracyMeters,
          bearing: fix.heading,
          timestamp: fix.at,
        ),
      );
    } on Object {
      /* A style reload can cancel a location update. */
    }
  }

  Future<void> _boot() async {
    final generation = ++_generation;
    try {
      final style = await const OfflineMapPackage().loadStyle(
        dark: _brightness == Brightness.dark,
      );
      final data = await ref.read(transitMapDataProvider.future);
      if (!mounted || generation != _generation) return;
      setState(() {
        _style = style;
        _data = data;
        _error = null;
        _ready = false;
      });
    } on Object catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    }
  }

  void _created(MapLibreMapController map) {
    _map = map;
    map.onFeatureTapped.add((point, coordinates, id, layer, annotation) {
      if (!mounted) return;
      if (layer.startsWith('transit.stop')) {
        final stop = _data?.stops[id];
        if (stop != null) widget.onStopTap?.call(stop);
      } else if (layer.startsWith('transit.route')) {
        final route = _data?.routes[id];
        if (route != null) widget.onRouteTap?.call(route);
      }
    });
  }

  Future<void> _styleLoaded() async {
    final map = _map, generation = _generation;
    if (map == null) return;
    bool current() =>
        mounted && generation == _generation && identical(map, _map);
    try {
      final empty = TransitMapData.collection([]);
      for (final direction in TransitDirectionKind.values) {
        final source = 'transit.routes.${direction.name}';
        await map.addGeoJsonSource(source, empty);
        if (!current()) return;
        await map.addLineLayer(
          source,
          'transit.route.${direction.name}.border',
          LineLayerProperties(
            lineColor: '#FFFFFF',
            lineWidth: 7,
            lineOpacity: .9,
            lineCap: 'round',
            lineJoin: 'round',
            lineDasharray: direction == TransitDirectionKind.vuelta
                ? [2, 2]
                : null,
          ),
          enableInteraction: false,
        );
        if (!current()) return;
        await map.addLineLayer(
          source,
          'transit.route.${direction.name}',
          LineLayerProperties(
            lineColor: ['get', 'color'],
            lineWidth: 4,
            lineCap: 'round',
            lineJoin: 'round',
            lineDasharray: direction == TransitDirectionKind.vuelta
                ? [2, 2]
                : null,
          ),
        );
        if (!current()) return;
        await map.addSymbolLayer(
          source,
          'transit.route.${direction.name}.arrows',
          const SymbolLayerProperties(
            symbolPlacement: 'line',
            symbolSpacing: 90,
            textField: '>',
            textFont: ['Noto Sans Bold'],
            textSize: 17,
            textColor: '#FFFFFF',
            textHaloColor: ['get', 'color'],
            textHaloWidth: 1.5,
            textRotationAlignment: 'map',
            textKeepUpright: false,
          ),
          minzoom: 13,
          enableInteraction: false,
        );
        if (!current()) return;
      }
      await map.addGeoJsonSource('transit.stops', empty);
      if (!current()) return;
      await map.addCircleLayer(
        'transit.stops',
        'transit.stop.circles',
        const CircleLayerProperties(
          circleRadius: 4,
          circleColor: '#FFFFFF',
          circleStrokeColor: '#B44910',
          circleStrokeWidth: 2,
        ),
        minzoom: 15,
      );
      if (!current()) return;
      await map.addSymbolLayer(
        'transit.stops',
        'transit.stop.names',
        SymbolLayerProperties(
          textField: ['get', 'name'],
          textFont: ['Noto Sans Regular'],
          textSize: 12,
          textAnchor: 'top',
          textOffset: [0, 1],
          textColor: _brightness == Brightness.dark ? '#F2F4F7' : '#202833',
          textHaloColor: _brightness == Brightness.dark ? '#141B24' : '#FFFFFF',
          textHaloWidth: 1.5,
        ),
        minzoom: 17,
      );
      if (!current()) return;
      for (final walking in [false, true]) {
        final source = walking ? 'journey.walk' : 'journey.transit';
        await map.addGeoJsonSource(source, empty);
        if (!current()) return;
        if (!walking) {
          await map.addLineLayer(
            source,
            '$source.border',
            const LineLayerProperties(
              lineColor: '#FFFFFF',
              lineWidth: [
                '+',
                ['get', 'width'],
                2,
              ],
              lineOpacity: ['get', 'opacity'],
              lineCap: 'round',
              lineJoin: 'round',
            ),
            enableInteraction: false,
          );
          if (!current()) return;
        }
        await map.addLineLayer(
          source,
          source,
          LineLayerProperties(
            lineColor: ['get', 'color'],
            lineWidth: ['get', 'width'],
            lineOpacity: ['get', 'opacity'],
            lineCap: 'round',
            lineJoin: 'round',
            lineDasharray: walking ? [1.5, 1.5] : null,
          ),
          enableInteraction: false,
        );
        if (!current()) return;
      }
      await map.addGeoJsonSource('journey.endpoints', empty);
      if (!current()) return;
      await map.addCircleLayer(
        'journey.endpoints',
        'journey.endpoint.circles',
        const CircleLayerProperties(
          circleRadius: 12,
          circleColor: ['get', 'color'],
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
        enableInteraction: false,
      );
      if (!current()) return;
      await map.addSymbolLayer(
        'journey.endpoints',
        'journey.endpoint.labels',
        const SymbolLayerProperties(
          textField: ['get', 'label'],
          textFont: ['Noto Sans Bold'],
          textSize: 13,
          textColor: '#FFFFFF',
          textAllowOverlap: true,
        ),
        enableInteraction: false,
      );
      if (!current()) return;
      _ready = true;
      await _redraw();
      if (!current()) return;
      await _fitFocusedLine();
      await _fitJourneys();
      await _position();
      if (current()) widget.onMapReady?.call();
    } on Object catch (error) {
      if (current()) setState(() => _error = error);
    }
  }

  Future<void> _redraw() async {
    final map = _map, data = _data, generation = _generation;
    if (map == null || data == null || !_ready) return;
    final previous = _drawing;
    final turn = _draw(map, data, generation, previous);
    _drawing = turn;
    await turn;
    if (identical(_drawing, turn)) _drawing = null;
  }

  Future<void> _draw(
    MapLibreMapController map,
    TransitMapData data,
    int generation,
    Future<void>? previous,
  ) async {
    if (previous != null) await previous;
    bool current() =>
        mounted && generation == _generation && _ready && identical(map, _map);
    if (!current()) return;
    try {
      for (final direction in TransitDirectionKind.values) {
        await map.setGeoJsonSource(
          'transit.routes.${direction.name}',
          data.routeFeatures(
            direction: direction,
            visible:
                (widget.focusedLineId != null || widget.showTransit) &&
                (widget.focusedDirection == null ||
                    widget.focusedDirection == direction),
            lineId: widget.focusedLineId,
          ),
        );
        if (!current()) return;
      }
      await map.setGeoJsonSource(
        'transit.stops',
        widget.showStops
            ? data.stopFeatures(
                lineId: widget.focusedLineId,
                direction: widget.focusedDirection,
              )
            : TransitMapData.collection([]),
      );
      if (!current()) return;
      await map.setGeoJsonSource(
        'journey.walk',
        TransitMapData.journeyFeatures(
          widget.journeys,
          walking: true,
          selected: widget.selectedJourney,
        ),
      );
      if (!current()) return;
      await map.setGeoJsonSource(
        'journey.transit',
        TransitMapData.journeyFeatures(
          widget.journeys,
          walking: false,
          selected: widget.selectedJourney,
        ),
      );
      if (!current()) return;
      await map.setGeoJsonSource(
        'journey.endpoints',
        TransitMapData.endpointFeatures(
          origin: widget.origin,
          destination: widget.destination,
        ),
      );
    } on Object catch (error) {
      if (current()) setState(() => _error = error);
    }
  }

  Future<void> _fitFocusedLine() async {
    final map = _map, id = widget.focusedLineId;
    if (map == null || !_ready || id == null) return;
    final points = <List<double>>[];
    for (final route in _data!.routes.values) {
      if (route.line.id == id &&
          (widget.focusedDirection == null ||
              route.direction.kind == widget.focusedDirection)) {
        points.addAll(route.direction.geometry);
      }
    }
    if (points.length < 2) return;
    final minLat = points.map((p) => p[0]).reduce(math.min),
        maxLat = points.map((p) => p[0]).reduce(math.max);
    final minLon = points.map((p) => p[1]).reduce(math.min),
        maxLon = points.map((p) => p[1]).reduce(math.max);
    try {
      await map.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLon),
            northeast: LatLng(maxLat, maxLon),
          ),
          left: 48,
          top: 120,
          right: 48,
          bottom: 240,
        ),
      );
    } on Object {
      /* A camera animation can be cancelled by a style reload. */
    }
  }

  Future<void> _fitJourneys() async {
    final map = _map;
    if (map == null || !_ready || widget.journeys.isEmpty) return;
    final points = widget.journeys
        .expand((t) => t.legs)
        .expand((leg) => leg.geometry)
        .toList();
    if (points.isEmpty) return;
    final minLat = points.map((p) => p.latitude).reduce(math.min),
        maxLat = points.map((p) => p.latitude).reduce(math.max);
    final minLon = points.map((p) => p.longitude).reduce(math.min),
        maxLon = points.map((p) => p.longitude).reduce(math.max);
    try {
      if ((maxLat - minLat).abs() < .000001 &&
          (maxLon - minLon).abs() < .000001) {
        await map.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(minLat, minLon), 15),
        );
      } else {
        await map.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLon),
              northeast: LatLng(maxLat, maxLon),
            ),
            left: 32,
            top: 32,
            right: 32,
            bottom: 32,
          ),
        );
      }
    } on Object {
      /* A style reload can cancel camera movement. */
    }
  }

  Future<void> flyTo({
    required double lat,
    required double lng,
    double zoom = 15,
  }) async {
    final map = _map;
    if (map != null) {
      await map.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), zoom),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ContentState(
        kind: ContentStateKind.error,
        message: context.l10n.mapError,
        onAction: () {
          setState(() {
            _error = null;
            _style = null;
            _ready = false;
            _map = null;
          });
          ref.invalidate(transitMapDataProvider);
          _boot();
        },
      );
    }
    if (_style == null) return const Center(child: CircularProgressIndicator());
    return MapLibreMap(
      styleString: _style!,
      minMaxZoomPreference: const MinMaxZoomPreference(0, 18),
      initialCameraPosition: const CameraPosition(
        target: LatLng(-16.3989, -71.5369),
        zoom: 13,
      ),
      onMapCreated: _created,
      onStyleLoadedCallback: _styleLoaded,
      onMapLongClick: (point, position) => widget.onLongPress?.call(
        GeoPoint(position.latitude, position.longitude),
      ),
      myLocationEnabled: widget.position != null,
      locationSource: const ManualLocationSource(),
      myLocationRenderMode: widget.position?.heading == null
          ? MyLocationRenderMode.normal
          : MyLocationRenderMode.gps,
      compassEnabled: false,
      attributionButtonMargins: const math.Point(8, 8),
      logoViewMargins: const math.Point(8, 8),
    );
  }
}
