import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowayki_lab/app/features/profile/presentation/screens/profile_screen.dart';
import 'package:gowayki_lab/app/features/game/ranking_screen.dart';
import 'package:gowayki_lab/app/game/weekly_scores.dart';
import 'package:gowayki_lab/app/community/community_providers.dart';
import 'package:gowayki_lab/app/sync/account_deletion_controller.dart';
import 'package:gowayki_lab/app/sync/personal_sync.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/providers/planner_providers.dart';
import 'package:gowayki_lab/core/models/auth_user.dart';
import 'package:gowayki_lab/domain/auth/auth_failure.dart';
import 'package:gowayki_lab/domain/game/weekly_ranking.dart';
import 'package:gowayki_lab/domain/community/community_report.dart';
import 'package:gowayki_lab/l10n/generated/app_localizations.dart';
import 'weekly_account_test.dart' show Session;

class RejectDelete extends AccountDeletionController {
  int calls = 0;
  @override
  Future<void> erase(String uid, {String? password}) async {
    calls++;
    state = true;
    try {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    } finally {
      state = false;
    }
  }
}

void main() {
  final closers = <VoidCallback>[];
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (final close in closers) {
      close();
    }
    closers.clear();
    await tester.pump();
  }

  Future<({ProviderContainer scope, RejectDelete deletion})> mount(
    WidgetTester tester,
    Widget child, {
    bool firebase = true,
    bool small = false,
    WeeklyRanking? ranking,
  }) async {
    SharedPreferences.setMockInitialValues({
      'game.preferences.v1': '{"version":1,"best":123,"sound":false}',
    });
    final session = Session()
      ..user = const AuthUser(
        id: 'alice',
        email: 'fixture@example.test',
        displayName: 'Nombre real del fixture',
        photoUrl: 'https://example.test/avatar.png',
        providers: ['password'],
      );
    final deletion = RejectDelete();
    final scope = ProviderContainer(
      overrides: [
        useFirebaseProvider.overrideWithValue(firebase),
        authRepositoryProvider.overrideWithValue(session),
        personalSyncProvider.overrideWith(() => LocalSync()),
        accountDeletionControllerProvider.overrideWith(() => deletion),
        myReportsProvider.overrideWith(
          (ref) => Stream.value(const ReportFeed([], fromCache: false)),
        ),
        weeklyRankingProvider.overrideWith((ref) async => ranking),
        appClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 7, 16)),
      ],
    );
    var closed = false;
    void close() {
      if (!closed) {
        closed = true;
        scope.dispose();
      }
    }

    closers.add(close);
    addTearDown(() async {
      close();
      await session.events.close();
    });
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
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (scope: scope, deletion: deletion);
  }

  testWidgets('ranking week rolls over at Monday midnight in Arequipa', (
    tester,
  ) async {
    var instant = DateTime.utc(2026, 11, 9, 4, 59, 59);
    final scope = ProviderContainer(
      overrides: [appClockProvider.overrideWithValue(() => instant)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Text(ref.watch(rankingWeekProvider)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('arequipa_2026-W45'), findsOneWidget);
    instant = DateTime.utc(2026, 11, 9, 5, 0, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('arequipa_2026-W46'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    scope.dispose();
    await tester.pump();
  });
  testWidgets(
    'profile uses session name, email, photo, city and persisted local record',
    (tester) async {
      await mount(tester, const ProfileScreen());
      expect(find.text('Nombre real del fixture'), findsOneWidget);
      expect(find.text('fixture@example.test'), findsOneWidget);
      expect(find.text('Arequipa'), findsOneWidget);
      expect(find.textContaining('123'), findsWidgets);
      expect(
        (tester.widget<Image>(find.byType(Image)).image as NetworkImage).url,
        'https://example.test/avatar.png',
      );
      await unmount(tester);
    },
  );
  testWidgets(
    'cancel deletion performs no action; bad password leaves dialog with translated error',
    (tester) async {
      final result = await mount(tester, const ProfileScreen());
      await tester.ensureVisible(find.byKey(const ValueKey('account.delete')));
      await tester.tap(find.byKey(const ValueKey('account.delete')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('account.delete.password')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result.deletion.calls, 0);
      await tester.tap(find.byKey(const ValueKey('account.delete')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('account.delete.password')),
        'Fixture',
      );
      await tester.tap(find.byKey(const ValueKey('account.delete.confirm')));
      await tester.pumpAndSettle();
      expect(result.deletion.calls, 1);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(AlertDialog)),
          ).authInvalidCredentials,
        ),
        findsWidgets,
      );
      expect(find.text('Cuenta y datos eliminados.'), findsNothing);
      await unmount(tester);
    },
  );
  testWidgets('ranking displays correct competition ranks and own position', (
    tester,
  ) async {
    const own = RankingScore(
      uid: 'alice',
      name: 'Nombre propio',
      score: 50,
      durationMs: 90000,
    );
    await mount(
      tester,
      const RankingScreen(),
      ranking: const WeeklyRanking(
        top: [
          RankingScore(
            uid: 'a',
            name: 'Primero',
            score: 100,
            durationMs: 90000,
          ),
          RankingScore(
            uid: 'b',
            name: 'Empatado',
            score: 100,
            durationMs: 90000,
          ),
          own,
        ],
        own: own,
        position: 3,
      ),
    );
    expect(find.text('Arequipa · Semana 45 de 2026'), findsOneWidget);
    expect(find.text('Tu puesto: 3 · 50 puntos'), findsOneWidget);
    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(rows.map((r) => (r.leading! as Text).data), ['1', '1', '3']);
    await unmount(tester);
  });
  testWidgets(
    'local profile hides remote deletion and ranking explains local records',
    (tester) async {
      await mount(tester, const ProfileScreen(), firebase: false);
      expect(find.byKey(const ValueKey('account.delete')), findsNothing);
      await unmount(tester);
      await mount(tester, const RankingScreen(), firebase: false);
      expect(find.textContaining('no está habilitado'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await unmount(tester);
    },
  );
}

class LocalSync extends PersonalSyncController {
  @override
  SyncStatus build() => SyncStatus.local;
}
