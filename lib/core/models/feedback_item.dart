enum FeedbackKind { bug, idea, other }

extension FeedbackKindApi on FeedbackKind {
  String get apiValue => name;
}

class FeedbackItem {
  const FeedbackItem({
    required this.kind,
    required this.message,
    this.cityCode,
  });

  final FeedbackKind kind;
  final String message;
  final String? cityCode;
}
