import '../community/community_report.dart';

abstract interface class ReportsRepository {
  String newId();
  Stream<ReportFeed> watchActive(DateTime since);
  Stream<ReportFeed> watchMine(String uid);
  Future<void> create(ReportDraft draft);
  Future<bool> confirm(String reportId);
  Future<void> delete(String reportId);
}
