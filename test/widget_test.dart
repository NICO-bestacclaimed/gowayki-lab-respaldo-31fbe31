import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/app.dart';
import 'package:gowayki_lab/data/service_locator.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_installer.dart';
import 'package:gowayki_lab/infra/city_pack/sqlite_city_pack_repository.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late SqliteCityPackRepository pack;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    support = await Directory.systemTemp.createTemp('gowayki-widget-test-');
    pack = await SqliteCityPackRepository.open(
      installer: CityPackInstaller(supportDirectory: () async => support),
    );
    await ServiceLocator.init(useFirebase: false, cityPackRepository: pack);
  });
  tearDownAll(() async {
    await pack.close();
    if (p.dirname(support.absolute.path) !=
            p.normalize(Directory.systemTemp.absolute.path) ||
        !p.basename(support.path).startsWith('gowayki-widget-test-')) {
      throw StateError('Unsafe test cleanup');
    }
    await support.delete(recursive: true);
  });

  testWidgets('arranca splash Gowayki Lab con paquete offline sin Firebase', (
    tester,
  ) async {
    expect((await ServiceLocator.transit.lines()).length, 98);
    expect(await ServiceLocator.places.search('tecsup arequipa'), isNotEmpty);
    await tester.pumpWidget(const GowaykiLabApp());
    expect(find.text('Gowayki Lab'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
  });
}
