import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/domain/planner/service_schedule.dart';
import 'package:gowayki_lab/infra/city_pack/city_pack_installer.dart';
import 'package:gowayki_lab/infra/city_pack/planner_network_loader.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'loads real SQLite patterns/config off the UI isolate without live database handles',
    () async {
      final support = await Directory.systemTemp.createTemp(
        'gowayki-planner-test-',
      );
      try {
        final installed = await CityPackInstaller(
          supportDirectory: () async => support,
        ).install();
        final network = await loadPlannerNetwork(installed);
        expect(installed.manifest.version, 2);
        expect(network.patterns.length, 191);
        expect(network.patterns.map((p) => p.lineId).toSet().length, 98);
        expect(network.stops.length, 6711);
        expect(
          network.patterns.fold<int>(0, (sum, p) => sum + p.visits.length),
          27258,
        );
        expect(
          network.transfers.values.fold<int>(
            0,
            (sum, edges) => sum + edges.length,
          ),
          170308,
        );
        expect(network.settings.frequencyAt(DateTime.utc(2026, 11, 6, 12)), 6);
        expect(network.settings.frequencyAt(DateTime.utc(2026, 11, 6, 17)), 10);
        expect(
          PlannerSettings.cityClock(DateTime.utc(2026, 11, 6, 12)).hour,
          7,
        );
      } finally {
        if (p.dirname(support.absolute.path) !=
                p.normalize(Directory.systemTemp.absolute.path) ||
            !p.basename(support.path).startsWith('gowayki-planner-test-')) {
          throw StateError('Unsafe test cleanup');
        }
        await support.delete(recursive: true);
      }
    },
  );
}
