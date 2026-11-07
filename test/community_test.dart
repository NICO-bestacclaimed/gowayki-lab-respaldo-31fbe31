import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/app/community/community_providers.dart';
import 'package:gowayki_lab/app/community/report_form.dart';
import 'package:gowayki_lab/app/community/report_widgets.dart';
import 'package:gowayki_lab/app/features/feedback/presentation/screens/feedback_screen.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/providers/planner_providers.dart';
import 'package:gowayki_lab/core/models/auth_user.dart';
import 'package:gowayki_lab/core/models/place_result.dart';
import 'package:gowayki_lab/core/models/transit_line.dart';
import 'package:gowayki_lab/core/models/feedback_item.dart';
import 'package:gowayki_lab/domain/community/community_report.dart';
import 'package:gowayki_lab/domain/repositories/reports_repository.dart';
import 'package:gowayki_lab/domain/repositories/feedback_repository.dart';
import 'package:gowayki_lab/infra/device/feedback_metadata.dart';
import 'package:gowayki_lab/l10n/generated/app_localizations.dart';

class Reports implements ReportsRepository {
  final drafts = <ReportDraft>[];
  final confirmations = <String>[];
  ReportFeed feed = const ReportFeed([], fromCache: false);
  bool fail = false;
  @override
  String newId() => 'draft-${drafts.length}';
  @override
  Stream<ReportFeed> watchActive(DateTime since) => Stream.value(feed);
  @override
  Stream<ReportFeed> watchMine(String uid) => Stream.value(feed);
  @override
  Future<void> create(ReportDraft draft) async {
    draft.validate();
    drafts.add(draft);
    if (fail) throw StateError('SDK English error must not be displayed');
  }

  @override
  Future<bool> confirm(String id) async {
    confirmations.add(id);
    return true;
  }

  @override
  Future<void> delete(String id) async {}
}

class FeedbackStore implements FeedbackRepository {
  final items = <FeedbackItem>[];
  bool fail = false;
  @override
  Future<void> submit(FeedbackItem item) async {
    items.add(item);
    if (fail) throw StateError('SDK English error must not be displayed');
  }
}

const point = PlaceResult(
  id: 'fixture-stop',
  name: 'Paradero de prueba',
  address: '',
  latitude: -16.4,
  longitude: -71.5,
);
const account = AuthUser(
  id: 'alice',
  email: 'fixture@example.test',
  displayName: 'Prueba',
);
final now = DateTime.utc(2026, 11, 7, 16);
CommunityReport report({Duration age = const Duration(hours: 1)}) =>
    CommunityReport(
      id: 'fixture-report',
      uid: 'alice',
      kind: ReportKind.detour,
      description: 'Aviso de prueba',
      latitude: -16.4,
      longitude: -71.5,
      createdAt: now.subtract(age),
      confirmations: 2,
      stopId: point.id,
    );
void main() {
  late ProviderContainer scope;
  late Reports reports;
  late FeedbackStore feedback;
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    bool firebase = true,
    AuthUser? user = account,
    bool small = false,
  }) async {
    reports = Reports();
    feedback = FeedbackStore();
    scope = ProviderContainer(
      overrides: [
        useFirebaseProvider.overrideWithValue(firebase),
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        cityLinesProvider.overrideWith(
          (ref) async => [
            const TransitLine(
              id: 'fixture-line',
              shortName: 'Línea de prueba',
              color: '#B44910',
              directions: [],
            ),
          ],
        ),
        reportsRepositoryProvider.overrideWithValue(reports),
        feedbackRepositoryProvider.overrideWithValue(feedback),
        feedbackMetadataProvider.overrideWith(
          (ref) async => const FeedbackMetadata(
            appVersion: '1.0.0+1',
            deviceModel: 'Fixture Windows',
            dataVersion: 2,
          ),
        ),
        appClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(scope.dispose);
    if (small) {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es', 'PE'),
          builder: small
              ? (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.8),
                    viewInsets: const EdgeInsets.only(bottom: 180),
                  ),
                  child: child!,
                )
              : null,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('72-hour visibility excludes exactly expired and future reports', () {
    expect(report().activeAt(now), true);
    expect(report(age: const Duration(hours: 72)).activeAt(now), false);
    expect(
      report(
        age: const Duration(hours: 72) - const Duration(microseconds: 1),
      ).activeAt(now),
      true,
    );
    expect(report(age: const Duration(hours: -1)).activeAt(now), false);
    expect(report().feature['geometry'], {
      'type': 'Point',
      'coordinates': [-71.5, -16.4],
    });
  });
  test('invalid reports and missing line relation are rejected locally', () {
    expect(
      () => const ReportDraft(
        id: 'x',
        kind: ReportKind.lineMissing,
        description: 'Reporte de prueba',
        latitude: -16,
        longitude: -71,
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const ReportDraft(
        id: 'x',
        kind: ReportKind.other,
        description: 'ok!',
        latitude: 91,
        longitude: -71,
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const ReportDraft(
        id: 'x',
        kind: ReportKind.lineMissing,
        description: 'Reporte de prueba',
        latitude: -16,
        longitude: -71,
        lineId: 'fixture-line',
      ).validate(),
      returnsNormally,
    );
  });
  testWidgets('reports expire while idle without restarting the server query', (
    tester,
  ) async {
    var instant = now;
    final backend = Reports()
      ..feed = ReportFeed([
        report(age: const Duration(hours: 72) - const Duration(seconds: 1)),
      ], fromCache: false);
    final container = ProviderContainer(
      overrides: [
        useFirebaseProvider.overrideWithValue(true),
        reportsRepositoryProvider.overrideWithValue(backend),
        appClockProvider.overrideWithValue(() => instant),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Text(
              '${ref.watch(activeReportsProvider).asData?.value.length ?? -1}',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    instant = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'anonymous report is gated and local mode never pretends to submit',
    (tester) async {
      await mount(
        tester,
        const ReportForm(point: point),
        user: const AuthUser(id: 'guest', email: '', isAnonymous: true),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('report.send')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('cuenta de correo'), findsOneWidget);
      expect(reports.drafts, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'form validates and sends real selected coordinates and stop id',
    (tester) async {
      await mount(tester, ReportForm(point: point, stopId: point.id));
      await tester.ensureVisible(find.byKey(const ValueKey('report.send')));
      await tester.tap(find.byKey(const ValueKey('report.send')));
      await tester.pumpAndSettle();
      expect(reports.drafts, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('report.message')),
        'El paradero necesita revisión',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('report.send')));
      await tester.tap(find.byKey(const ValueKey('report.send')));
      await tester.pumpAndSettle();
      expect(reports.drafts.single.latitude, point.latitude);
      expect(reports.drafts.single.longitude, point.longitude);
      expect(reports.drafts.single.stopId, point.id);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'network failure preserves report text and retries the same draft id',
    (tester) async {
      await mount(tester, const ReportForm(point: point));
      reports.fail = true;
      await tester.enterText(
        find.byKey(const ValueKey('report.message')),
        'Aviso de prueba',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('report.send')));
      await tester.tap(find.byKey(const ValueKey('report.send')));
      await tester.pumpAndSettle();
      expect(find.text('Aviso de prueba'), findsOneWidget);
      expect(find.textContaining('SDK English'), findsNothing);
      final id = reports.drafts.single.id;
      await tester.tap(find.byKey(const ValueKey('report.send')));
      await tester.pumpAndSettle();
      expect(reports.drafts.last.id, id);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'one confirmation disables repeated taps and anonymous user cannot confirm',
    (tester) async {
      await mount(tester, ReportCard(report: report()));
      await tester.tap(find.text('👍 Sigue así'));
      await tester.pumpAndSettle();
      expect(reports.confirmations, ['fixture-report']);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'feedback sends metadata and never shows success after an error',
    (tester) async {
      await mount(tester, const FeedbackScreen());
      feedback.fail = true;
      await tester.enterText(
        find.byKey(const ValueKey('feedback.message')),
        'Información de prueba',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('feedback.send')));
      await tester.tap(find.byKey(const ValueKey('feedback.send')));
      await tester.pumpAndSettle();
      expect(feedback.items.single.metadata!.dataVersion, 2);
      expect(feedback.items.single.metadata!.appVersion, '1.0.0+1');
      expect(feedback.items.single.metadata!.deviceModel, 'Fixture Windows');
      expect(find.text('Información de prueba'), findsOneWidget);
      expect(find.textContaining('SDK English'), findsNothing);
      expect(find.text('¡Gracias por tu comentario!'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('local-only help disables remote submission', (tester) async {
    await mount(tester, const FeedbackScreen(), firebase: false, user: null);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('feedback.send')))
          .onPressed,
      isNull,
    );
    expect(feedback.items, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('report form and keyboard fit on small screens with large text', (
    tester,
  ) async {
    await mount(
      tester,
      const ReportForm(point: point, lineId: 'fixture-line'),
      small: true,
    );
    await tester.enterText(
      find.byKey(const ValueKey('report.message')),
      'Prueba de pantalla pequeña',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('report.send')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
