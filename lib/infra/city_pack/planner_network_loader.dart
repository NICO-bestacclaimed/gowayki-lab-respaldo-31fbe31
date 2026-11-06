import 'dart:isolate';
import '../../domain/planner/planner_network.dart';
import 'city_pack_installer.dart';
import 'sqlite_planner_network_reader.dart';

/// Load a verified install off the UI isolate; never send a SQLite handle.
Future<PlannerNetwork> loadPlannerNetwork(InstalledCityPack installed) {
  final path = installed.databasePath;
  return Isolate.run(() => readPlannerNetwork(path));
}
