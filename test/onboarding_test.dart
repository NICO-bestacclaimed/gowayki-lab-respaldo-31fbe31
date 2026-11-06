import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/app.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/router/app_router.dart';
import 'package:gowayki_lab/app/features/location/presentation/screens/location_disclosure_screen.dart';
import 'package:gowayki_lab/app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:gowayki_lab/data/app_services.dart';
import 'package:gowayki_lab/domain/repositories/location_permission_repository.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_installer.dart';
import 'package:gowayki_lab/shared/brand/brand_assets.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class TestLocationPermission implements LocationPermissionRepository {
  TestLocationPermission({
    this.initial = LocationAccess.denied,
    this.result = LocationAccess.allowed,
  });
  final LocationAccess initial, result;
  int checks = 0, requests = 0, settings = 0;
  @override
  Future<LocationAccess> check() async {
    checks++;
    return initial;
  }

  @override
  Future<LocationAccess> request() async {
    requests++;
    return result;
  }

  @override
  Future<bool> openSettings() async {
    settings++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'logo and all fifteen delivered illustrations retain their original hashes',
    () {
      final manifest =
          jsonDecode(File('tool/data/artwork_sources.json').readAsStringSync())
              as Map<String, dynamic>;
      final records = (manifest['files'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(BrandAssets.micros, hasLength(15));
      expect(BrandAssets.micros.toSet(), hasLength(15));
      expect(records, hasLength(16));
      for (final item in records) {
        final bytes = File(item['asset'] as String).readAsBytesSync();
        expect(sha256.convert(bytes).toString(), item['sha256']);
      }
    },
  );
  testWidgets(
    'onboarding shows the three required messages and finishes after the last',
    (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinish: () => finished++)),
      );
      expect(find.text('Encuentra tu combi'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding.next')));
      await tester.pumpAndSettle();
      expect(find.text('Sabe dónde bajar'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding.next')));
      await tester.pumpAndSettle();
      expect(find.text('Llega a tiempo (tiempos estimados)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding.next')));
      expect(finished, 1);
    },
  );
  testWidgets('onboarding is scrollable on a small screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: OnboardingScreen(onFinish: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('onboarding.next')), findsOneWidget);
  });
  testWidgets('permission is never requested before an explicit user action', (
    tester,
  ) async {
    final permissions = TestLocationPermission();
    var continued = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationPermissionRepositoryProvider.overrideWithValue(permissions),
        ],
        child: MaterialApp(
          home: LocationDisclosureScreen(
            onContinue: () async {
              continued++;
            },
          ),
        ),
      ),
    );
    expect(find.text('Tu ubicación, tú decides'), findsOneWidget);
    expect(permissions.checks, 0);
    expect(permissions.requests, 0);
    await tester.tap(find.text('Continuar sin ubicación'));
    await tester.pumpAndSettle();
    expect(continued, 1);
    expect(permissions.requests, 0);
  });
  testWidgets('accepting permission requests it once and continues', (
    tester,
  ) async {
    final permissions = TestLocationPermission();
    var continued = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationPermissionRepositoryProvider.overrideWithValue(permissions),
        ],
        child: MaterialApp(
          home: LocationDisclosureScreen(
            onContinue: () async {
              continued++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Permitir ubicación'));
    await tester.pumpAndSettle();
    expect(permissions.requests, 1);
    expect(continued, 1);
  });
  testWidgets('denial stays optional and permanent denial offers settings', (
    tester,
  ) async {
    final denied = TestLocationPermission(result: LocationAccess.denied);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationPermissionRepositoryProvider.overrideWithValue(denied),
        ],
        child: MaterialApp(
          home: LocationDisclosureScreen(onContinue: () async {}),
        ),
      ),
    );
    await tester.tap(find.text('Permitir ubicación'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'El permiso no se concedió. Puedes continuar y cambiarlo más adelante.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    final permanent = TestLocationPermission(
      initial: LocationAccess.permanentlyDenied,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationPermissionRepositoryProvider.overrideWithValue(permanent),
        ],
        child: MaterialApp(
          home: LocationDisclosureScreen(onContinue: () async {}),
        ),
      ),
    );
    await tester.tap(find.text('Permitir ubicación'));
    await tester.pumpAndSettle();
    expect(permanent.requests, 0);
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pumpAndSettle();
    expect(permanent.settings, 1);
  });

  group('first launch routing', () {
    late Directory support;
    late AppServices services;
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      support = await Directory.systemTemp.createTemp('gowayki-intro-test-');
      services = await AppServices.open(
        useFirebase: false,
        installer: CityPackInstaller(supportDirectory: () async => support),
      );
    });
    tearDownAll(() async {
      await services.close();
      if (p.dirname(support.absolute.path) !=
              p.normalize(Directory.systemTemp.absolute.path) ||
          !p.basename(support.path).startsWith('gowayki-intro-test-')) {
        throw StateError('Unsafe test cleanup');
      }
      await support.delete(recursive: true);
    });
    testWidgets(
      'explains location before marking intro done and does not repeat next launch',
      (tester) async {
        final permissions = TestLocationPermission();
        ProviderContainer scope() => ProviderContainer(
          overrides: [
            appServicesProvider.overrideWithValue(AsyncData(services)),
            locationPermissionRepositoryProvider.overrideWithValue(permissions),
            explorePageBuilderProvider.overrideWithValue(
              (context) => const Scaffold(body: Text('Explorar de prueba')),
            ),
          ],
        );
        var container = scope();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const GowaykiLabApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Encuentra tu combi'), findsOneWidget);
        await tester.tap(find.text('Omitir'));
        await tester.pumpAndSettle();
        expect(find.text('Tu ubicación, tú decides'), findsOneWidget);
        expect(services.localPreferences.getBool('onboarding.done'), isNull);
        expect(permissions.requests, 0);
        await tester.tap(find.text('Continuar sin ubicación'));
        await tester.pumpAndSettle();
        expect(services.localPreferences.getBool('onboarding.done'), isTrue);
        expect(find.text('Explorar de prueba'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        container = scope();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const GowaykiLabApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Explorar de prueba'), findsOneWidget);
        expect(find.text('Encuentra tu combi'), findsNothing);
        expect(permissions.requests, 0);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  });
}
