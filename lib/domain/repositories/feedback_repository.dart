import '../../core/models/feedback_item.dart';

abstract interface class FeedbackRepository {
  Future<void> submit(FeedbackItem item);
}
