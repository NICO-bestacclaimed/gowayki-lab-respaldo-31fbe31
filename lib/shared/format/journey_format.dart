import '../../domain/planner/service_schedule.dart';

String cityTime(DateTime instant) {
  final time = PlannerSettings.cityClock(instant);
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String cityDateTime(DateTime instant) {
  final time = PlannerSettings.cityClock(instant);
  return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} ${cityTime(instant)}';
}
