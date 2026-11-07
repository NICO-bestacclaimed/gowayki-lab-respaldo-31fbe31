import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/planner/planner_network.dart';
import '../../domain/planner/planner_worker.dart';
import '../../domain/repositories/journey_planner_client.dart';
import '../settings/app_settings.dart';
import 'app_providers.dart';

final plannerNetworkProvider = FutureProvider<PlannerNetwork>((ref) async {
  final services = await ref.watch(appServicesProvider.future);
  return services.cityPack.plannerNetwork();
});
final plannerClientProvider = FutureProvider<JourneyPlannerClient>((ref) async {
  ref.watch(
    appSettingsProvider.select((value) => value.asData?.value.maxAccessMeters),
  );
  PlannerWorker? owned;
  ref.onDispose(() {
    final worker = owned;
    if (worker != null) unawaited(worker.close());
  });
  final network = await ref.watch(plannerNetworkProvider.future);
  final settings = await ref.read(appSettingsProvider.future);
  if (!ref.mounted) throw StateError('Planner initialization cancelled');
  final worker = await PlannerWorker.start(
    network.withSettings(settings.plannerSettings(network.settings)),
  );
  if (!ref.mounted) {
    await worker.close();
    throw StateError('Planner initialization cancelled');
  }
  owned = worker;
  return worker;
}, retry: (count, error) => null);

final appClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
