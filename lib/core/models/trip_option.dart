class TripOption {
  const TripOption({
    required this.id,
    required this.summary,
    required this.durationMinutes,
    required this.transferCount,
    required this.legs,
  });

  final String id;
  final String summary;
  final int durationMinutes;
  final int transferCount;
  final List<String> legs;
}
