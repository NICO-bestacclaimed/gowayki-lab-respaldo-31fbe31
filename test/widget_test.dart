import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/app.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/data/app_services.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_installer.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late AppServices services;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    support = await Directory.systemTemp.createTemp('gowayki-widget-test-');
    services = await AppServices.open(
      useFirebase: false,
      installer: CityPackInstaller(supportDirectory: () async => support),
    );
  });
  tearDownAll(() async {
    await services.close();
    if (p.dirname(support.absolute.path) !=
            p.normalize(Directory.systemTemp.absolute.path) ||
        !p.basename(support.path).startsWith('gowayki-widget-test-')) {
      throw StateError('Unsafe test cleanup');
    }
    await support.delete(recursive: true);
  });
  testWidgets('muestra splash mientras carga y abre bienvenida sin Firebase', (
    tester,
  ) async {
    final pending = Completer<AppServices>();
    final container = ProviderContainer(
      overrides: [appServicesProvider.overrideWith((ref) => pending.future)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const GowaykiLabApp(),
      ),
    );
    expect(find.byKey(const ValueKey('brand.splash.logo')), findsOneWidget);
    expect((await services.transit.lines()).length, 98);
    expect(await services.places.search('tecsup arequipa'), isNotEmpty);
    pending.complete(services);
    await tester.pumpAndSettle();
    expect(find.text('Encuentra tu combi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets('muestra error de carga y permite reintentar', (tester) async {
    var attempts = 0;
    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        appServicesProvider.overrideWith((ref) async {
          if (++attempts == 1) throw StateError('test-only failure');
          return services;
        }),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const GowaykiLabApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos preparar los datos de Arequipa.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Encuentra tu combi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
