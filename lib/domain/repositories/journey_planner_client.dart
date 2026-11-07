import '../planner/journey_planner.dart';

abstract interface class JourneyPlannerClient {
  Future<JourneyResponse> plan(JourneyRequest request, {DateTime? now});
  Future<void> close();
}
