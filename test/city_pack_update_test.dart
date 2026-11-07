import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:gowayki_lab/app.dart';
import 'package:gowayki_lab/app/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/updates/city_update_controller.dart';
import 'package:gowayki_lab/domain/updates/city_update.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_installer.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_updater.dart';
import 'package:gowayki_lab/infra/city_pack/sqlite_city_pack_repository.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

class Source implements CityUpdateRepository {
  Source(this.value);
  final CityUpdateMetadata? value;
  int checks = 0;
  @override
  Future<CityUpdateMetadata?> check() async {
    checks++;
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // This suite serves only loopback fixtures; bypass Flutter's HTTP-400 test mock.
  final httpOverride = HttpOverrides.current;
  HttpOverrides.global = null;
  tearDownAll(() {
    HttpOverrides.global = httpOverride;
  });
  late Directory fixture, base;
  late HttpServer server;
  late CityPackInstaller installer;
  late InstalledCityPack previous;
  late CityPackUpdater updater;
  late Map<String, dynamic> manifest;
  bool corrupt = false, truncate = false, redirect = false;
  CityUpdateMetadata metadata({String? hash, String min = '1.0.0', Uri? url}) =>
      CityUpdateMetadata(
        version: 3,
        sha256: hash ?? manifest['sha256'] as String,
        bytes: manifest['size_bytes'] as int,
        minAppVersion: min,
        dataUrl:
            url ?? Uri.parse('http://127.0.0.1:${server.port}/v3/pack.sqlite'),
      );
  Matcher problem(UpdateProblem value) => isA<CityUpdateException>().having(
    (error) => error.problem,
    'problem',
    value,
  );
  Future<void> clean(Directory dir, String prefix) async {
    if (p.dirname(p.normalize(dir.absolute.path)) !=
            p.normalize(Directory.systemTemp.absolute.path) ||
        !p.basename(dir.path).startsWith(prefix)) {
      throw StateError('Unsafe test cleanup');
    }
    await dir.delete(recursive: true);
  }

  Future<void> unchanged() async {
    expect((await installer.install()).manifest.version, 2);
    expect(await File(previous.databasePath).exists(), isTrue);
    final root = await installer.updateRoot();
    expect(
      await root
          .list()
          .where((entry) => p.basename(entry.path).startsWith('download-'))
          .length,
      0,
    );
  }

  setUpAll(() async {
    fixture = await Directory.systemTemp.createTemp('gowayki-update-fixture-');
    manifest =
        jsonDecode(
              await rootBundle.loadString('assets/city/arequipa/manifest.json'),
            )
            as Map<String, dynamic>;
    for (final name in ['pack.sqlite', 'routes.geojson']) {
      final data = await rootBundle.load('assets/city/arequipa/$name');
      await File(p.join(fixture.path, name)).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    final db = sqlite3.open(p.join(fixture.path, 'pack.sqlite'));
    db.execute("UPDATE config SET value_json='3' WHERE key='data_version'");
    db.close();
    final bytes = await File(p.join(fixture.path, 'pack.sqlite')).readAsBytes();
    manifest['version'] = 3;
    manifest['size_bytes'] = bytes.length;
    manifest['sha256'] = sha256.convert(bytes).toString();
    (manifest['files'] as Map<String, dynamic>)['pack.sqlite'] = {
      'bytes': bytes.length,
      'sha256': manifest['sha256'],
    };
    await File(
      p.join(fixture.path, 'manifest.json'),
    ).writeAsString(jsonEncode(manifest));
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        final name = request.uri.pathSegments.last;
        if (redirect) {
          request.response.statusCode = 302;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            'http://example.invalid/pack.sqlite',
          );
        } else if ([
          'manifest.json',
          'pack.sqlite',
          'routes.geojson',
        ].contains(name)) {
          var bytes = await File(p.join(fixture.path, name)).readAsBytes();
          if (name == 'pack.sqlite' && corrupt) {
            bytes[1000] ^= 1;
          }
          if (name == 'pack.sqlite' && truncate) {
            bytes = bytes.sublist(0, 1000);
          }
          request.response.add(bytes);
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      } on Object {
        /* A cancelled client is expected in the cancellation test. */
      }
    });
  });
  tearDownAll(() async {
    await server.close(force: true);
    await clean(fixture, 'gowayki-update-fixture-');
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    corrupt = truncate = redirect = false;
    base = await Directory.systemTemp.createTemp('gowayki-update-test-');
    installer = CityPackInstaller(
      supportDirectory: () async => base,
      appVersion: () async => '1.0.0',
    );
    previous = await installer.install();
    updater = CityPackUpdater(installer: installer, allowLoopbackHttp: true);
  });
  tearDown(() async {
    updater.cancel();
    await clean(base, 'gowayki-update-test-');
  });

  test(
    'real v3 downloads, activates atomically, survives restart; old reader remains usable',
    () async {
      final oldReader = SqliteCityPackRepository.openInstalled(previous);
      addTearDown(oldReader.close);
      final data = metadata();
      expect(updater.shouldDownload(data, previous, '1.0.0'), isTrue);
      final staged = await updater.download(data);
      final next = await installer.activateUpdate(
        stage: staged.directory,
        source: staged.source,
        manifest: staged.manifest,
        minimum: staged.minimum,
        previous: previous,
      );
      await staged.discard();
      final reopened = await installer.install();
      expect(reopened.manifest.version, 3);
      expect(reopened.databasePath, next.databasePath);
      expect((await oldReader.lines()).length, 98);
      expect((await oldReader.packageInfo()).version, 2);
      final newReader = SqliteCityPackRepository.openInstalled(reopened);
      expect((await newReader.lines()).length, 98);
      expect((await newReader.mapStops()), isNotEmpty);
      await newReader.close();
      await oldReader.close();
      await installer.rollbackUpdate(previous);
      await unchanged();
    },
  );
  test(
    'wrong announced SHA rejects before activation and preserves offline data',
    () async {
      await expectLater(
        updater.download(metadata(hash: 'f' * 64)),
        throwsA(problem(UpdateProblem.integrity)),
      );
      await unchanged();
    },
  );
  test('corrupted payload with correct manifest is rejected', () async {
    corrupt = true;
    await expectLater(
      updater.download(metadata()),
      throwsA(problem(UpdateProblem.integrity)),
    );
    await unchanged();
  });
  test(
    'truncated payload is rejected without leaving temporary files',
    () async {
      truncate = true;
      await expectLater(
        updater.download(metadata()),
        throwsA(problem(UpdateProblem.integrity)),
      );
      await unchanged();
    },
  );
  test(
    'minimum app version, immutable build conflict, HTTPS and redirects are enforced',
    () async {
      expect(
        () => updater.shouldDownload(metadata(min: '2.0.0'), previous, '1.0.0'),
        throwsA(problem(UpdateProblem.incompatibleApp)),
      );
      expect(
        () => CityPackUpdater(
          installer: installer,
        ).shouldDownload(metadata(), previous, '1.0.0'),
        throwsA(problem(UpdateProblem.invalidMetadata)),
      );
      final same = CityUpdateMetadata(version: 2, sha256: 'a' * 64, bytes: 100);
      expect(
        () => updater.shouldDownload(same, previous, '1.0.0'),
        throwsA(problem(UpdateProblem.conflict)),
      );
      redirect = true;
      await expectLater(
        updater.download(metadata()),
        throwsA(problem(UpdateProblem.invalidMetadata)),
      );
      await unchanged();
    },
  );
  test('cancelled download preserves current data', () async {
    await expectLater(
      updater.download(
        metadata(),
        progress: (received, total) {
          updater.cancel();
        },
      ),
      throwsA(problem(UpdateProblem.cancelled)),
    );
    await unchanged();
  });
  test(
    'corrupt active build falls back to the previous verified build',
    () async {
      final staged = await updater.download(metadata());
      final next = await installer.activateUpdate(
        stage: staged.directory,
        source: staged.source,
        manifest: staged.manifest,
        minimum: staged.minimum,
        previous: previous,
      );
      await staged.discard();
      await File(next.databasePath).writeAsBytes([1, 2, 3], flush: true);
      await unchanged();
      await File(
        p.join((await installer.updateRoot()).path, 'active.json'),
      ).writeAsString('{broken');
      await unchanged();
    },
  );
  test(
    'controller reopens v3; failed reload rolls back and reopens v2',
    () async {
      for (final fail in [false, true]) {
        await installer.rollbackUpdate(previous);
        var reloads = 0;
        final source = Source(metadata());
        late ProviderContainer container;
        container = ProviderContainer(
          overrides: [
            useFirebaseProvider.overrideWithValue(false),
            cityPackInstallerProvider.overrideWithValue(installer),
            cityPackUpdaterProvider.overrideWithValue(updater),
            cityUpdateRepositoryProvider.overrideWithValue(source),
            cityUpdateAllowedProvider.overrideWithValue(true),
            if (fail)
              reloadCityPackProvider.overrideWithValue(() async {
                reloads++;
                container.invalidate(appServicesProvider);
                final services = await container.read(
                  appServicesProvider.future,
                );
                if (reloads == 1) {
                  throw StateError('injected reload failure');
                }
                return (await services.cityPack.packageInfo()).version;
              }),
          ],
        );
        final old = await container.read(appServicesProvider.future);
        addTearDown(() async {
          final current = container.read(appServicesProvider).asData?.value;
          container.dispose();
          await old.close();
          await current?.close();
        });
        await container.read(cityUpdateProvider.notifier).checkAndApply();
        final state = container.read(cityUpdateProvider);
        expect(source.checks, 1);
        expect(state.phase, fail ? UpdatePhase.failed : UpdatePhase.complete);
        expect(
          (await container
                  .read(appServicesProvider.future)
                  .then((s) => s.cityPack.packageInfo()))
              .version,
          fail ? 2 : 3,
        );
        if (fail) {
          expect(reloads, 2);
        }
      }
    },
  );
  testWidgets('the complete app reloads data and shows the update result', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding.done', true);
    final container = ProviderContainer(
      overrides: [
        useFirebaseProvider.overrideWithValue(false),
        cityPackInstallerProvider.overrideWithValue(installer),
        cityPackUpdaterProvider.overrideWithValue(updater),
        cityUpdateRepositoryProvider.overrideWithValue(Source(metadata())),
        cityUpdateAllowedProvider.overrideWithValue(true),
        initialLocationProvider.overrideWithValue('/ajustes'),
        explorePageBuilderProvider.overrideWithValue(
          (context) => const Scaffold(body: Text('Explore test surface')),
        ),
      ],
    );
    final old = await tester.runAsync(
      () => container.read(appServicesProvider.future),
    );
    addTearDown(() async {
      final current = container.read(appServicesProvider).asData?.value;
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.runAsync(() async {
        await old?.close();
        await current?.close();
      });
    });
    await old!.auth.signInAnonymously();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const GowaykiLabApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => container.read(cityUpdateProvider.notifier).checkAndApply(),
    );
    await tester.pumpAndSettle();
    expect(container.read(cityUpdateProvider).phase, UpdatePhase.complete);
    expect(
      container
          .read(appServicesProvider)
          .requireValue
          .auth
          .currentUser
          ?.isAnonymous,
      isTrue,
    );
    expect(
      container.read(appServicesProvider).requireValue.cityPack,
      isA<SqliteCityPackRepository>(),
    );
    expect(find.textContaining('3'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  test('controller refuses during a trip without fetching metadata', () async {
    final source = Source(metadata());
    final container = ProviderContainer(
      overrides: [
        cityUpdateAllowedProvider.overrideWithValue(false),
        cityUpdateRepositoryProvider.overrideWithValue(source),
      ],
    );
    await container.read(cityUpdateProvider.notifier).checkAndApply();
    expect(
      container.read(cityUpdateProvider).problem,
      UpdateProblem.activeTrip,
    );
    expect(source.checks, 0);
    container.dispose();
  });
}
