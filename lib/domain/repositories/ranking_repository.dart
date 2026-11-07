import '../game/weekly_ranking.dart';

abstract interface class RankingRepository {
  Future<WeeklyRanking> load(String week, {String? uid});
  Future<int> publish(String uid, String name, PendingScore score);
}
