enum FeedbackKind { bug, idea, incorrectData, other }

extension FeedbackKindApi on FeedbackKind {
  String get apiValue =>
      this == FeedbackKind.incorrectData ? 'incorrect_data' : name;
}

class FeedbackMetadata {
  const FeedbackMetadata({
    required this.appVersion,
    required this.deviceModel,
    required this.dataVersion,
  });
  final String appVersion, deviceModel;
  final int dataVersion;
}

class FeedbackItem {
  const FeedbackItem({
    required this.kind,
    required this.message,
    this.cityCode = 'arequipa',
    this.id,
    this.metadata,
  });
  final FeedbackKind kind;
  final String message;
  final String? cityCode, id;
  final FeedbackMetadata? metadata;
}
