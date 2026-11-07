/// ISO week in Arequipa (UTC-05:00, no daylight-saving transitions).
String rankingWeek(DateTime instant) {
  final lima = instant.toUtc().subtract(const Duration(hours: 5));
  final day = DateTime.utc(lima.year, lima.month, lima.day);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final week =
      thursday.difference(DateTime.utc(thursday.year, 1, 1)).inDays ~/ 7 + 1;
  return 'arequipa_${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

class RankingScore {
  const RankingScore({
    required this.uid,
    required this.name,
    required this.score,
    required this.durationMs,
  });
  final String uid, name;
  final int score, durationMs;
}

class WeeklyRanking {
  const WeeklyRanking({required this.top, this.own, this.position});
  final List<RankingScore> top;
  final RankingScore? own;
  final int? position;
}

class PendingScore {
  const PendingScore(this.week, this.score, this.durationMs);
  final String week;
  final int score, durationMs;
  Map<String, Object?> toJson() => {
    'week': week,
    'score': score,
    'durationMs': durationMs,
  };
  factory PendingScore.fromJson(Map<String, dynamic> data) {
    final week = data['week'] as String,
        score = data['score'] as int,
        duration = data['durationMs'] as int;
    if (!RegExp(
          r'^arequipa_[0-9]{4}-W(0[1-9]|[1-4][0-9]|5[0-3])$',
        ).hasMatch(week) ||
        score < 0 ||
        score > 5000 ||
        duration < 1000 ||
        duration > 120000 ||
        score > duration / 1000 * 30 + 30) {
      throw const FormatException('Invalid weekly score');
    }
    return PendingScore(week, score, duration);
  }
}
