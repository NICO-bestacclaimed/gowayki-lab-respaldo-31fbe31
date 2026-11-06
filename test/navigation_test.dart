import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/app.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/router/app_router.dart';
import 'package:gowayki_lab/app/features/explorer/presentation/widgets/combis_sheet.dart';
import 'package:gowayki_lab/core/models/transit_line.dart';
import 'package:gowayki_lab/data/app_services.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_installer.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late ProviderContainer container;
  late AppServices services;
  late CityPackInstaller installer;
  late List<TransitLine> preparedLines;
  ProviderContainer scope() => ProviderContainer(
    overrides: [
      cityPackInstallerProvider.overrideWithValue(installer),
      initialLocationProvider.overrideWithValue('/rutas'),
      explorePageBuilderProvider.overrideWithValue(
        (context) =>
            const Scaffold(body: Center(child: Text('Explorar de prueba'))),
      ),
    ],
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding.done': true});
    support = await Directory.systemTemp.createTemp('gowayki-navigation-test-');
    installer = CityPackInstaller(supportDirectory: () async => support);
    container = scope();

    services = await container.read(appServicesProvider.future);

    preparedLines = await container.read(cityLinesProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await services.close();
    if (p.dirname(support.absolute.path) !=
            p.normalize(Directory.systemTemp.absolute.path) ||
        !p.basename(support.path).startsWith('gowayki-navigation-test-')) {
      throw StateError('Unsafe test cleanup');
    }
    await support.delete(recursive: true);
  });
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const GowaykiLabApp(),
    ),
  );

  testWidgets(
    'cuatro pestañas, favoritos vacíos y perfil sin datos inventados',
    (tester) async {
      await mount(tester);

      await tester.pumpAndSettle();
      for (final key in [
        'nav.explore',
        'nav.lines',
        'nav.favorites',
        'nav.profile',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('nav.explore')));
      await tester.pumpAndSettle();
      expect(find.text('Explorar de prueba'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav.favorites')));
      await tester.pumpAndSettle();
      expect(
        find.text('Aún no tienes líneas favoritas. Guarda una desde Rutas.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('nav.profile')));
      await tester.pumpAndSettle();
      expect(find.text('No hay sesión iniciada.'), findsOneWidget);
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Ciudad activa'), findsOneWidget);
      container.read(appRouterProvider).pop();
      await tester.pumpAndSettle();
      expect(find.text('No hay sesión iniciada.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'guardar y quitar favoritos actualiza las pestañas y el almacenamiento',
    (tester) async {
      final line = preparedLines.first;

      await mount(tester);

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('favorite-${line.id}')));

      await tester.pumpAndSettle();
      expect(
        services.localPreferences.getStringList(FavoriteLineIds.storageKey),
        [line.id],
      );
      await tester.tap(find.byKey(const ValueKey('nav.favorites')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('line-${line.id}')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('favorite-${line.id}')));

      await tester.pumpAndSettle();
      expect(
        find.text('Aún no tienes líneas favoritas. Guarda una desde Rutas.'),
        findsOneWidget,
      );
      expect(
        services.localPreferences.getStringList(FavoriteLineIds.storageKey),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'cambios simultáneos de favoritos se conservan al recrear proveedores',
    () async {
      final lines = await container.read(cityLinesProvider.future);
      final notifier = container.read(favoriteLineIdsProvider.notifier);
      await Future.wait([
        notifier.toggle(lines[0].id),
        notifier.toggle(lines[1].id),
      ]);
      expect(container.read(favoriteLineIdsProvider), {
        lines[0].id,
        lines[1].id,
      });
      container.dispose();
      await services.close();
      container = scope();

      services = await container.read(appServicesProvider.future);

      expect(container.read(favoriteLineIdsProvider), {
        lines[0].id,
        lines[1].id,
      });
      expect(services.useFirebase, isFalse);
    },
  );

  testWidgets('la lista de combis ordena una copia de las líneas inmutables', (
    tester,
  ) async {
    TransitLine? selected;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => CombisSheet.open(
                  context,
                  onSelected: (line) => selected = line,
                ),
                child: const Text('Abrir combis'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir combis'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final first = preparedLines.first;
    await tester.enterText(find.byType(TextField), first.shortName);
    await tester.pumpAndSettle();
    expect(find.text(first.shortName), findsWidgets);
    await tester.tap(find.text(first.shortName).last);
    await tester.pumpAndSettle();
    expect(selected?.shortName, first.shortName);
    await tester.pumpWidget(const SizedBox());
  });
}
