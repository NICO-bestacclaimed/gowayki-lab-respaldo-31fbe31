import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../../core/models/transit_line.dart';
import '../../../../providers/app_providers.dart';
import '../../../../../infra/map/offline_map_package.dart';
import '../../../../../shared/theme/theme.dart';

/// Mapa MapLibre offline + capas de combis (ida / vuelta).
class ExplorerMap extends ConsumerStatefulWidget {
  const ExplorerMap({
    super.key,
    this.showTransit = true,
    this.focusedLineId,
    this.focusedDirection,
    this.onMapReady,
  });

  final bool showTransit;
  final String? focusedLineId;

  /// `null` = ambos sentidos (si la combi está enfocada).
  final TransitDirectionKind? focusedDirection;
  final VoidCallback? onMapReady;

  @override
  ConsumerState<ExplorerMap> createState() => ExplorerMapState();
}

class ExplorerMapState extends ConsumerState<ExplorerMap> {
  static const _srcIda = 'lab-ida';
  static const _srcVuelta = 'lab-vuelta';

  String? _style;
  Object? _styleError;
  MapLibreMapController? _map;
  bool _ready = false;
  List<TransitLine> _lines = const [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void didUpdateWidget(covariant ExplorerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    if (oldWidget.showTransit != widget.showTransit ||
        oldWidget.focusedLineId != widget.focusedLineId ||
        oldWidget.focusedDirection != widget.focusedDirection) {
      _redraw();
    }
  }

  Future<void> _boot() async {
    try {
      final style = await const OfflineMapPackage().loadStyle();
      final lines = await ref.read(transitNetworkRepositoryProvider).lines();
      if (!mounted) return;
      setState(() {
        _style = style;
        _lines = lines;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _styleError = e);
    }
  }

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null) return;
    const empty = {'type': 'FeatureCollection', 'features': <Object>[]};
    await map.addGeoJsonSource(_srcIda, empty);
    await map.addGeoJsonSource(_srcVuelta, empty);

    await map.addLineLayer(
      _srcIda,
      'lab-ida-casing',
      const LineLayerProperties(
        lineColor: '#ffffff',
        lineWidth: 7,
        lineCap: 'round',
        lineJoin: 'round',
        lineOpacity: 0.9,
      ),
      enableInteraction: false,
    );
    await map.addLineLayer(
      _srcIda,
      'lab-ida',
      LineLayerProperties(
        lineColor: _hex(AppColors.transitIda),
        lineWidth: 4,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      enableInteraction: false,
    );

    await map.addLineLayer(
      _srcVuelta,
      'lab-vuelta-casing',
      const LineLayerProperties(
        lineColor: '#ffffff',
        lineWidth: 7,
        lineCap: 'round',
        lineJoin: 'round',
        lineOpacity: 0.9,
        lineDasharray: [1, 1.5],
      ),
      enableInteraction: false,
    );
    await map.addLineLayer(
      _srcVuelta,
      'lab-vuelta',
      LineLayerProperties(
        lineColor: _hex(AppColors.transitVuelta),
        lineWidth: 4,
        lineCap: 'round',
        lineJoin: 'round',
        lineDasharray: [2, 2],
      ),
      enableInteraction: false,
    );

    _ready = true;
    await _redraw();
    widget.onMapReady?.call();
  }

  String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  Future<void> _redraw() async {
    final map = _map;
    if (map == null || !_ready) return;

    final focusId = widget.focusedLineId;
    final focusDir = widget.focusedDirection;
    final showAll = focusId == null && widget.showTransit;

    final idaGeoms = <List<List<double>>>[];
    final vueltaGeoms = <List<List<double>>>[];

    for (final line in _lines) {
      if (focusId != null && line.id != focusId) continue;
      if (focusId == null && !showAll) continue;

      for (final d in line.directions) {
        if (focusDir != null && d.kind != focusDir) continue;
        if (d.kind == TransitDirectionKind.ida) {
          idaGeoms.add(d.geometry);
        } else {
          vueltaGeoms.add(d.geometry);
        }
      }
    }

    await map.setGeoJsonSource(_srcIda, _collection(idaGeoms));
    await map.setGeoJsonSource(_srcVuelta, _collection(vueltaGeoms));

    final showIda = idaGeoms.isNotEmpty;
    final showVuelta = vueltaGeoms.isNotEmpty;
    await map.setLayerVisibility('lab-ida-casing', showIda);
    await map.setLayerVisibility('lab-ida', showIda);
    await map.setLayerVisibility('lab-vuelta-casing', showVuelta);
    await map.setLayerVisibility('lab-vuelta', showVuelta);

    if (focusId != null) {
      TransitLine? line;
      for (final l in _lines) {
        if (l.id == focusId) {
          line = l;
          break;
        }
      }
      if (line != null) await _fitLine(line, focusDir);
    }
  }

  Map<String, dynamic> _collection(List<List<List<double>>> geoms) {
    return {
      'type': 'FeatureCollection',
      'features': geoms
          .map(
            (g) => {
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': {
                'type': 'LineString',
                'coordinates': g
                    .map((p) => [p[1], p[0]])
                    .toList(growable: false),
              },
            },
          )
          .toList(growable: false),
    };
  }

  Future<void> _fitLine(TransitLine line, TransitDirectionKind? only) async {
    final map = _map;
    if (map == null) return;
    final pts = <List<double>>[];
    for (final d in line.directions) {
      if (only != null && d.kind != only) continue;
      pts.addAll(d.geometry);
    }
    if (pts.length < 2) return;
    var minLat = pts.first[0];
    var maxLat = minLat;
    var minLng = pts.first[1];
    var maxLng = minLng;
    for (final p in pts) {
      if (p[0] < minLat) minLat = p[0];
      if (p[0] > maxLat) maxLat = p[0];
      if (p[1] < minLng) minLng = p[1];
      if (p[1] > maxLng) maxLng = p[1];
    }
    await map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 48,
        top: 120,
        right: 48,
        bottom: 200,
      ),
    );
  }

  Future<void> flyTo({required double lat, required double lng}) async {
    final map = _map;
    if (map == null) return;
    await map.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15));
  }

  @override
  Widget build(BuildContext context) {
    if (_styleError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.l10n.mapError, textAlign: TextAlign.center),
        ),
      );
    }
    final style = _style;
    if (style == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return MapLibreMap(
      styleString: style,
      initialCameraPosition: const CameraPosition(
        target: LatLng(-16.3989, -71.5369),
        zoom: 13,
      ),
      onMapCreated: (c) => _map = c,
      onStyleLoadedCallback: _onStyleLoaded,
      myLocationEnabled: false,
      compassEnabled: false,
      attributionButtonMargins: const math.Point(8, 8),
      logoViewMargins: const math.Point(8, 8),
    );
  }
}
