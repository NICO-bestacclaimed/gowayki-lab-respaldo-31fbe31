import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/transit_line.dart';
import '../../domain/models/city_pack_models.dart';
import '../../domain/planner/service_schedule.dart';
import 'app_providers.dart';
import 'map_providers.dart';

final cityPlannerSettingsProvider = FutureProvider<PlannerSettings>((
  ref,
) async {
  final services = await ref.watch(appServicesProvider.future);
  return PlannerSettings.fromConfig(await services.cityPack.configuration());
});

class LineDetailsData {
  LineDetailsData({
    required this.line,
    required this.patterns,
    required this.visits,
    required this.settings,
    this.fare,
  });
  final TransitLine line;
  final List<CityPattern> patterns;
  final Map<String, List<CityPatternStop>> visits;
  final PlannerSettings settings;
  final CityFare? fare;
}

final lineDetailsProvider = FutureProvider.autoDispose
    .family<LineDetailsData, String>((ref, id) async {
      final services = await ref.watch(appServicesProvider.future);
      final line = (await services.cityPack.lines())
          .where((line) => line.id == id)
          .firstOrNull;
      if (line == null) throw StateError('Unknown line');
      final patterns = await services.cityPack.patternsForLine(id);
      final visits = <String, List<CityPatternStop>>{};
      for (final pattern in patterns) {
        visits[pattern.id] = await services.cityPack.patternStops(pattern.id);
      }
      return LineDetailsData(
        line: line,
        patterns: patterns,
        visits: visits,
        fare: await services.cityPack.fareForLine(id),
        settings: await ref.watch(cityPlannerSettingsProvider.future),
      );
    });

class StopDetailsData {
  const StopDetailsData(this.entry, this.lines, this.settings);
  final CityMapStop entry;
  final Map<String, TransitLine> lines;
  final PlannerSettings settings;
}

final stopDetailsProvider = FutureProvider.autoDispose
    .family<StopDetailsData, String>((ref, id) async {
      final services = await ref.watch(appServicesProvider.future);
      final stop = await services.cityPack.stop(id);
      if (stop == null) throw StateError('Unknown stop');
      final map = await ref.watch(transitMapDataProvider.future);
      return StopDetailsData(
        map.stops[id] ?? CityMapStop(stop: stop, services: const []),
        {for (final line in map.lines) line.id: line},
        await ref.watch(cityPlannerSettingsProvider.future),
      );
    });
