import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/explorer/map/transit_map_data.dart';
import 'app_providers.dart';

final transitMapDataProvider = FutureProvider<TransitMapData>((ref) async {
  final services = await ref.watch(appServicesProvider.future);
  final stops = await services.cityPack.mapStops();
  return TransitMapData(lines: await services.cityPack.lines(), stops: stops);
});
