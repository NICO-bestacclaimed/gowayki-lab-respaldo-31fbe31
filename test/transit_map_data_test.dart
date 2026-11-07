import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/app/features/explorer/map/transit_map_data.dart';
import 'package:gowayki_lab/core/models/transit_line.dart';
import 'package:gowayki_lab/domain/models/city_pack_models.dart';
import 'package:gowayki_lab/domain/planner/itinerary.dart';
import 'package:gowayki_lab/infra/city_pack/sqlite_map_reader.dart';

void main() {
  const ida = TransitDirection(
    kind: TransitDirectionKind.ida,
    routeId: 'r1',
    headsign: 'Destino',
    longName: 'Ida',
    geometry: [
      [-16.4, -71.5],
      [-16.5, -71.6],
    ],
  );
  const vuelta = TransitDirection(
    kind: TransitDirectionKind.vuelta,
    routeId: 'r2',
    headsign: 'Origen',
    longName: 'Vuelta',
    geometry: [
      [-16.5, -71.6],
      [-16.4, -71.5],
    ],
  );
  const line = TransitLine(
    id: 'line',
    shortName: 'Prueba',
    color: '#123456',
    directions: [ida, vuelta],
  );
  const stop = CityStop(
    id: 'stop',
    name: 'Nombre estimado',
    latitude: -16.4,
    longitude: -71.5,
    sourceKind: 'gtfs_candidate',
    nameSource: 'estimated',
    needsReview: true,
    usedInPatterns: true,
  );
  final data = TransitMapData(
    lines: [line],
    stops: [
      CityMapStop(
        stop: stop,
        services: const [
          CityStopService(
            lineId: 'line',
            patternId: 'p1',
            routeId: 'r1',
            direction: 'ida',
            headsign: 'Destino',
          ),
        ],
      ),
    ],
  );
  test(
    'colores, sentidos, coordenadas y selección mantienen sus identidades',
    () {
      final feature =
          (data.routeFeatures(direction: TransitDirectionKind.ida)['features']
                  as List)
              .single;
      expect(feature['id'], 'r1');
      expect(feature['properties']['color'], '#123456');
      expect(feature['geometry']['coordinates'].first, [-71.5, -16.4]);
      expect(data.routes['r1']!.line.id, 'line');
      expect(data.routes['r2']!.direction.kind, TransitDirectionKind.vuelta);
      expect(
        data.routeFeatures(
          direction: TransitDirectionKind.ida,
          visible: false,
        )['features'],
        isEmpty,
      );
      expect(
        data.routeFeatures(
          direction: TransitDirectionKind.ida,
          lineId: 'unknown',
        )['features'],
        isEmpty,
      );
    },
  );
  test(
    'paraderos se filtran por línea y sentido y señalan nombres estimados',
    () {
      final visible =
          data.stopFeatures(
                lineId: 'line',
                direction: TransitDirectionKind.ida,
              )['features']
              as List;
      expect(visible.single['id'], 'stop');
      expect(visible.single['properties']['name'], '~ Nombre estimado');
      expect(
        data.stopFeatures(
          lineId: 'line',
          direction: TransitDirectionKind.vuelta,
        )['features'],
        isEmpty,
      );
      expect(data.stopFeatures(lineId: 'unknown')['features'], isEmpty);
      expect(data.stops['stop']!.services.single.routeId, 'r1');
    },
  );
  test('origen y destino usan puntos reales y desaparecen al borrarlos', () {
    final features =
        TransitMapData.endpointFeatures(
              origin: GeoPoint(-16.4, -71.5),
              destination: GeoPoint(-16.5, -71.6),
            )['features']
            as List;
    expect(features.map((f) => f['properties']['label']), ['A', 'B']);
    expect(features.first['geometry']['coordinates'], [-71.5, -16.4]);
    expect(TransitMapData.endpointFeatures()['features'], isEmpty);
  });
  test(
    'lector real carga 6128 puntos usados con asociaciones válidas en isolate',
    () async {
      final stops = await Isolate.run(
        () => readMapStops('assets/city/arequipa/pack.sqlite'),
      );
      expect(stops, hasLength(6128));
      expect(stops.map((s) => s.stop.id).toSet(), hasLength(6128));
      expect(
        stops.every((s) => s.stop.usedInPatterns && s.services.isNotEmpty),
        isTrue,
      );
      expect(
        stops.expand((s) => s.services).map((s) => s.lineId).toSet(),
        hasLength(98),
      );
      expect(
        stops
            .expand((s) => s.services)
            .every((s) => ['ida', 'vuelta'].contains(s.direction)),
        isTrue,
      );
    },
  );
}
