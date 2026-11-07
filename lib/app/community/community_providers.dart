import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/community/community_report.dart';
import '../../domain/repositories/reports_repository.dart';
import '../../data/firebase/firestore_reports_repository.dart';
import '../providers/app_providers.dart';
import '../providers/planner_providers.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => FirestoreReportsRepository(),
);
final reportsRawProvider = StreamProvider.autoDispose<ReportFeed>((ref) {
  if (!ref.watch(useFirebaseProvider)) {
    return Stream.value(const ReportFeed([], fromCache: false));
  }
  return ref
      .watch(reportsRepositoryProvider)
      .watchActive(
        ref
            .read(appClockProvider)()
            .toUtc()
            .subtract(const Duration(hours: 72)),
      );
});
final activeReportsProvider =
    Provider.autoDispose<AsyncValue<List<CommunityReport>>>((ref) {
      final raw = ref.watch(reportsRawProvider),
          now = ref.watch(appClockProvider)().toUtc();
      final active = raw.asData?.value.items
          .where((r) => r.activeAt(now))
          .toList();
      if (active != null && active.isNotEmpty) {
        final next = active
            .map((r) => r.expiresAt)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final timer = Timer(
          next.difference(now) + const Duration(milliseconds: 1),
          ref.invalidateSelf,
        );
        ref.onDispose(timer.cancel);
      }
      return raw.whenData(
        (rows) => List.unmodifiable(rows.items.where((r) => r.activeAt(now))),
      );
    });
final myReportsProvider = StreamProvider.autoDispose<List<CommunityReport>>((
  ref,
) {
  if (!ref.watch(useFirebaseProvider)) return Stream.value(const []);
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null || user.isAnonymous) return Stream.value(const []);
  return ref
      .watch(reportsRepositoryProvider)
      .watchMine(user.id)
      .map((feed) => feed.items);
});
