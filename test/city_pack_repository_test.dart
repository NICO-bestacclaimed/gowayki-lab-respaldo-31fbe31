import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_installer.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_manifest.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_place_search_repository.dart';
import 'package:gowayki_lab/infra/city_pack/sqlite_city_pack_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const assetRoot = 'assets/city/arequipa';

class RecordingBundle extends CachingAssetBundle {
  final loads = <String, int>{};
  final overrides = <String, ByteData>{};
  @override
  Future<ByteData> load(String key) async {
    loads.update(key, (n) => n + 1, ifAbsent: () => 1);
    return overrides[key] ?? await rootBundle.load(key);
  }

  void text(String key, String value) {
    overrides[key] = ByteData.sublistView(
      Uint8List.fromList(utf8.encode(value)),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory base;
  late RecordingBundle bundle;
  late CityPackInstaller installer;
  late SqliteCityPackRepository repository;
  late String manifestSource;

  setUpAll(() async {
    base = await Directory.systemTemp.createTemp('gowayki-pack-test-');
    bundle = RecordingBundle();
    installer = CityPackInstaller(
      bundle: bundle,
      supportDirectory: () async => base,
    );
    manifestSource = await rootBundle.loadString('$assetRoot/manifest.json');
    repository = await SqliteCityPackRepository.open(installer: installer);
  });
  tearDownAll(() async {
    await repository.close();
    if (p.dirname(base.absolute.path) !=
            p.normalize(Directory.systemTemp.absolute.path) ||
        !p.basename(base.path).startsWith('gowayki-pack-test-')) {
      throw StateError('Unsafe test cleanup');
    }
    await base.delete(recursive: true);
  });

  test(
    'installs the real asset and reuses verified files without copying',
    () async {
      final installed = repository.installed;
      final original = await rootBundle.load('$assetRoot/pack.sqlite');
      final file = File(installed.databasePath);
      expect(
        sha256.convert(await file.readAsBytes()).toString(),
        repository.manifest.sha256,
      );
      expect(await file.length(), original.lengthInBytes);
      final modified = await file.lastModified();
      final again = await installer.install();
      expect(again.databasePath, installed.databasePath);
      expect(await file.lastModified(), modified);
      expect(bundle.loads['$assetRoot/pack.sqlite'], 1);
      expect(bundle.loads['$assetRoot/routes.geojson'], 1);
    },
  );

  test(
    'actual line exposes ordered stops and geometry in map coordinate order',
    () async {
      final lines = await repository.lines();
      expect(lines, hasLength(98));
      var count = 0;
      for (final line in lines) {
        final patterns = await repository.patternsForLine(line.id);
        count += patterns.length;
        expect(patterns.length, line.directions.length);
        for (final pattern in patterns) {
          final stops = await repository.patternStops(pattern.id);
          expect(stops.length, greaterThanOrEqualTo(5));
          final shape = (await repository.shape(pattern.shapeId))!;
          expect(shape.vertexDistances.length, shape.coordinates.length);
          expect(
            shape.vertexDistances.last,
            closeTo(pattern.lengthMeters, 0.00001),
          );
          for (var i = 0; i < stops.length; i++) {
            expect(stops[i].sequence, i + 1);
            expect(stops[i].offsetMeters, lessThanOrEqualTo(35.000002));
            expect(stops[i].stop.name.trim(), isNotEmpty);
            expect(
              stops[i].distanceMeters,
              inInclusiveRange(0, pattern.lengthMeters + .00001),
            );
            if (i > 0) {
              expect(
                stops[i].distanceMeters,
                greaterThanOrEqualTo(stops[i - 1].distanceMeters),
              );
            }
          }
          final direction = line.directions.singleWhere(
            (d) => d.routeId == pattern.routeId,
          );
          expect(direction.geometry.first, [
            shape.coordinates.first[1],
            shape.coordinates.first[0],
          ]);
          expect(direction.geometry.first[0], inInclusiveRange(-17, -16));
          expect(direction.geometry.first[1], inInclusiveRange(-72, -71));
        }
      }
      expect(count, 191);
    },
  );

  test(
    'FTS finds actual TECSUP and ignores accents in real place names',
    () async {
      final tecsup = await repository.searchPlaces('tecsup arequipa');
      expect(tecsup.any((p) => p.category == 'institute'), isTrue);
      final a = await repository.searchPlaces('Ejercito');
      final b = await repository.searchPlaces('Ejército');
      expect(a, isNotEmpty);
      expect(a.map((p) => p.id), b.map((p) => p.id));
      final adapter = await CityPackPlaceSearchRepository(
        repository,
      ).search('tecsup arequipa');
      expect(adapter.first.id, tecsup.first.id);
    },
  );

  test(
    'arequipa finds Arequípa in an isolated FTS fixture, not in shipped data',
    () async {
      final source = File(repository.installed.databasePath);
      final fixture = await source.copy(
        p.join(base.path, 'accent-fixture.sqlite'),
      );
      final db = sqlite3.open(fixture.path);
      try {
        db.execute(
          '''
        INSERT INTO places(place_id,name,category,latitude,longitude,osm_type,osm_id,
          coordinate_source,aliases,address,tags_json)
        VALUES(?,?,?,?,?,?,?,?,?,?,?)
      ''',
          [
            'test:accent',
            'Arequípa',
            'test_only',
            -16.4,
            -71.5,
            'test',
            -1,
            'test_only',
            '',
            '',
            '{}',
          ],
        );
        db.execute('INSERT INTO places_fts(places_fts) VALUES(?)', ['rebuild']);
      } finally {
        db.close();
      }
      // Use the same repository API by installing the explicitly test-only bundle.
      final fixtureBytes = await fixture.readAsBytes();
      final manifest = jsonDecode(manifestSource) as Map<String, dynamic>;
      final hash = sha256.convert(fixtureBytes).toString();
      manifest['version'] = 2;
      manifest['sha256'] = hash;
      manifest['size_bytes'] = fixtureBytes.length;
      manifest['files']['pack.sqlite'] = {
        'bytes': fixtureBytes.length,
        'sha256': hash,
      };
      final fixtureBundle = RecordingBundle()
        ..text('$assetRoot/manifest.json', jsonEncode(manifest));
      fixtureBundle.overrides['$assetRoot/pack.sqlite'] = ByteData.sublistView(
        fixtureBytes,
      );
      final fixtureRepo = await SqliteCityPackRepository.open(
        installer: CityPackInstaller(
          bundle: fixtureBundle,
          supportDirectory: () async => base,
        ),
      );
      try {
        final found = await fixtureRepo.searchPlaces('arequipa', limit: 100);
        expect(
          found.any((p) => p.id == 'test:accent' && p.name == 'Arequípa'),
          isTrue,
        );
        expect(
          (await repository.searchPlaces(
            'arequipa',
            limit: 100,
          )).any((p) => p.id == 'test:accent'),
          isFalse,
        );
      } finally {
        await fixtureRepo.close();
      }
    },
  );

  test('paged stops, missing IDs, FTS punctuation and query limits', () async {
    final a = await repository.stops(limit: 2);
    final b = await repository.stops(limit: 1, offset: 1);
    expect(a[1].id, b.single.id);
    expect((await repository.stop(a.first.id))!.id, a.first.id);
    expect(await repository.stop("' OR 1=1 --"), isNull);
    expect(await repository.patternsForLine('missing'), isEmpty);
    expect(await repository.patternStops('missing'), isEmpty);
    expect(await repository.shape('missing'), isNull);
    expect(await repository.searchPlaces('  " * : - '), isEmpty);
    expect(await repository.searchPlaces('tecsup"'), isNotEmpty);
    expect(await repository.searchPlaces('zzzznoplaceresult'), isEmpty);
    await expectLater(repository.stops(limit: 0), throwsRangeError);
    await expectLater(repository.stops(offset: -1), throwsRangeError);
    await expectLater(
      repository.searchPlaces('a', limit: 101),
      throwsRangeError,
    );
    await expectLater(repository.searchPlaces('a' * 513), throwsArgumentError);
  });

  test('config, default fare and symmetric walking transfers', () async {
    final config = await repository.configuration();
    expect(config['walking_speed_m_per_min'], 75);
    expect(config['access_max_m'], 800);
    expect(config['access_fallback_max_m'], 1500);
    expect(config['frequency_minutes_by_period'], {
      'peak': 6,
      'off_peak': 10,
      'night': 15,
    });
    final bands = config['speed_bands'] as List<dynamic>;
    expect(bands.last['speed_kmh'], isNull);
    final line = (await repository.lines()).first;
    final fare = (await repository.fareForLine(line.id))!;
    expect(fare.amount, 1);
    expect(fare.currency, 'PEN');
    expect(await repository.fareForLine('missing'), isNull);
    final stop = (await repository.stops(limit: 1)).single;
    final edges = await repository.transfersFrom(stop.id);
    expect(edges, isNotEmpty);
    final edge = edges.first;
    expect(edge.walkMeters, closeTo(edge.directMeters * 1.3, .00001));
    final reverse = await repository.transfersFrom(edge.toStopId);
    expect(
      reverse.any(
        (e) => e.toStopId == stop.id && e.walkMeters == edge.walkMeters,
      ),
      isTrue,
    );
  });

  test(
    'manifest distinguishes newer, older and a different build at same version',
    () {
      final local = repository.manifest;
      CityPackManifest variant(void Function(Map<String, dynamic>) change) {
        final data = jsonDecode(manifestSource) as Map<String, dynamic>;
        change(data);
        return CityPackManifest.parse(jsonEncode(data));
      }

      expect(repository.compareVersion(local), CityPackVersionStatus.current);
      expect(
        repository.compareVersion(variant((m) => m['version'] = 2)),
        CityPackVersionStatus.updateAvailable,
      );
      final newer = variant((m) => m['version'] = 2);
      expect(newer.compare(local), CityPackVersionStatus.localNewer);
      expect(
        repository.compareVersion(
          variant((m) {
            m['sha256'] = '0' * 64;
            m['files']['pack.sqlite']['sha256'] = '0' * 64;
          }),
        ),
        CityPackVersionStatus.differentBuild,
      );
    },
  );

  test(
    'rejects unsupported and unsafe manifests before accessing payloads',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (m) => m['schema_version'] = 99,
        (m) => m['city_code'] = '../other',
        (m) => m['version'] = 0,
        (m) => m['version'] = 1.5,
        (m) => m['sha256'] = '0' * 64,
        (m) => m['files']['pack.sqlite']['bytes'] = -1,
        (m) => m['files']['../outside'] = {'bytes': 1, 'sha256': '0' * 64},
      ]) {
        final data = jsonDecode(manifestSource) as Map<String, dynamic>;
        mutate(data);
        expect(
          () => CityPackManifest.parse(jsonEncode(data)),
          throwsA(isA<CityPackException>()),
        );
      }
      expect(
        () => CityPackManifest.parse('{'),
        throwsA(isA<CityPackException>()),
      );
    },
  );

  test('concurrent installers share one valid build', () async {
    final result = await Future.wait([
      installer.install(),
      installer.install(),
    ]);
    expect(result[0].databasePath, result[1].databasePath);
    expect(bundle.loads['$assetRoot/pack.sqlite'], 1);
  });

  test('bad incoming hash leaves last good installation usable', () async {
    final changed = jsonDecode(manifestSource) as Map<String, dynamic>;
    changed['version'] = 3;
    changed['sha256'] = '0' * 64;
    changed['files']['pack.sqlite']['sha256'] = '0' * 64;
    final bad = RecordingBundle()
      ..text('$assetRoot/manifest.json', jsonEncode(changed));
    await expectLater(
      CityPackInstaller(
        bundle: bad,
        supportDirectory: () async => base,
      ).install(),
      throwsA(isA<CityPackException>()),
    );
    expect((await repository.lines()).length, 98);
    expect(await File(repository.installed.databasePath).exists(), isTrue);
    final temporary = await Directory(
      p.join(base.path, 'city', 'arequipa'),
    ).list().toList();
    expect(
      temporary.whereType<Directory>().any(
        (d) => p.basename(d.path).startsWith('install-'),
      ),
      isFalse,
    );
  });

  test('repairs corrupt local files and close rejects later queries', () async {
    // Close before replacing the file, including on Windows.
    await repository.close();
    await File(
      repository.installed.databasePath,
    ).writeAsBytes([0, 1, 2], flush: true);
    repository = await SqliteCityPackRepository.open(installer: installer);
    expect((await repository.lines()).length, 98);
    expect(bundle.loads['$assetRoot/pack.sqlite'], 2);
    final disposable = await SqliteCityPackRepository.open(
      installer: installer,
    );
    await disposable.close();
    await disposable.close();
    await expectLater(disposable.lines(), throwsStateError);
    await expectLater(disposable.searchPlaces('tecsup'), throwsStateError);
  });
}
