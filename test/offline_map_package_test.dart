import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:gowayki_lab/infra/map/offline_map_package.dart';

class MapBundle extends CachingAssetBundle {
  final overrides = <String, ByteData>{};
  final loads = <String, int>{};
  @override
  Future<ByteData> load(String key) async {
    loads.update(key, (v) => v + 1, ifAbsent: () => 1);
    return overrides[key] ?? await rootBundle.load(key);
  }

  void text(String key, String value) {
    evict(key);
    overrides[key] = ByteData.sublistView(
      Uint8List.fromList(utf8.encode(value)),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory base;
  late MapBundle bundle;
  late OfflineMapPackage map;
  setUp(() async {
    base = await Directory.systemTemp.createTemp('gowayki-map-test-');
    bundle = MapBundle();
    map = OfflineMapPackage(bundle: bundle, supportDirectory: () async => base);
  });
  tearDown(() async {
    if (p.dirname(p.normalize(base.absolute.path)) !=
            p.normalize(Directory.systemTemp.absolute.path) ||
        !p.basename(base.path).startsWith('gowayki-map-test-')) {
      throw StateError('Unsafe cleanup');
    }
    await base.delete(recursive: true);
  });
  test('claro y oscuro resuelven MBTiles y glifos locales sin red', () async {
    for (final dark in [false, true]) {
      final text = await map.loadStyle(dark: dark);
      expect(text, isNot(contains('{MAP_DIR}')));
      final style = jsonDecode(text) as Map<String, dynamic>;
      final source = style['sources']['openmaptiles'];
      expect(source['url'], startsWith('mbtiles://'));
      expect(source['maxzoom'], 14);
      expect(style['glyphs'], startsWith('file://'));
      final uriPath = (source['url'] as String).substring('mbtiles://'.length);
      expect(await File(uriPath).exists(), isTrue);
      expect(
        (style['layers'] as List).first['paint']['background-color'],
        dark ? '#141b24' : '#eef1f4',
      );
    }
    expect(bundle.loads['assets/map/arequipa.mbtiles'], 1);
  });
  test(
    'concurrencia publica una copia; una instalación dañada se repara',
    () async {
      final copies = await Future.wait([
        map.install(),
        map.install(),
        map.install(),
      ]);
      expect(copies.map((d) => d.path).toSet(), hasLength(1));
      expect(bundle.loads['assets/map/arequipa.mbtiles'], 1);
      await File(
        p.join(copies.first.path, 'arequipa.mbtiles'),
      ).writeAsString('broken');
      final repaired = await map.install();
      expect(repaired.path, copies.first.path);
      expect(bundle.loads['assets/map/arequipa.mbtiles'], 2);
      expect(
        Directory(p.join(base.path, 'map'))
            .listSync()
            .whereType<Directory>()
            .where((d) => p.basename(d.path).contains('.invalid-')),
        hasLength(1),
      );
    },
  );
  test(
    'fallo de nueva copia conserva la anterior y limpia solo staging',
    () async {
      final previous = await map.install();
      final original = await File(
        p.join(previous.path, 'arequipa.mbtiles'),
      ).readAsBytes();
      final metadata =
          jsonDecode(await rootBundle.loadString('assets/map/manifest.json'))
              as Map<String, dynamic>;
      metadata['revision_test'] = 2;
      bundle.text('assets/map/manifest.json', jsonEncode(metadata));
      bundle.text('assets/map/arequipa.mbtiles', 'invalid data');
      await expectLater(map.install(), throwsFormatException);
      expect(
        await File(p.join(previous.path, 'arequipa.mbtiles')).readAsBytes(),
        original,
      );
      expect(
        Directory(p.join(base.path, 'map'))
            .listSync()
            .whereType<Directory>()
            .where((d) => p.basename(d.path).startsWith('install-')),
        isEmpty,
      );
    },
  );
  test(
    'manifest con ruta fuera de mapa se rechaza antes de escribir',
    () async {
      final metadata =
          jsonDecode(await rootBundle.loadString('assets/map/manifest.json'))
              as Map<String, dynamic>;
      metadata['files']['../escape'] = {'bytes': 1, 'sha256': '0' * 64};
      bundle.text('assets/map/manifest.json', jsonEncode(metadata));
      await expectLater(map.install(), throwsFormatException);
      expect(await File(p.join(base.path, 'escape')).exists(), isFalse);
      expect(await Directory(p.join(base.path, 'map')).exists(), isFalse);
    },
  );
  test(
    'manifest cubre todos los assets y el padre z14 existe al acercar z18',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('assets/map/manifest.json'))
              as Map<String, dynamic>;
      final files = manifest['files'] as Map<String, dynamic>;
      for (final entry in files.entries) {
        final data = await rootBundle.load('assets/map/${entry.key}');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        expect(bytes.length, entry.value['bytes']);
        expect(sha256.convert(bytes).toString(), entry.value['sha256']);
      }
      final assets = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(
        assets
            .listAssets()
            .where(
              (key) =>
                  key.startsWith('assets/map/') &&
                  key != 'assets/map/manifest.json',
            )
            .toSet(),
        files.keys.map((key) => 'assets/map/$key').toSet(),
      );
      final db = sqlite3.open(
        'assets/map/arequipa.mbtiles',
        mode: OpenMode.readOnly,
      );
      try {
        expect(
          db.select('select max(zoom_level) as z from tiles').single['z'],
          14,
        );
        const lat = -16.3989, lon = -71.5369;
        final n = 1 << 18;
        final x18 = ((lon + 180) / 360 * n).floor();
        final rad = lat * math.pi / 180;
        final y18 =
            ((1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) /
                    2 *
                    n)
                .floor();
        final x14 = x18 >> 4, y14 = y18 >> 4;
        final row = (1 << 14) - 1 - y14;
        final parent = db.select(
          'select length(tile_data) as bytes from tiles where zoom_level=14 and tile_column=? and tile_row=?',
          [x14, row],
        );
        expect(parent.single['bytes'], greaterThan(0));
      } finally {
        db.close();
      }
    },
  );
}
