import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/l10n/l10n.dart';
import '../../game/weekly_scores.dart';
import '../../providers/app_providers.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n,
        enabled = ref.watch(useFirebaseProvider),
        week = ref.watch(rankingWeekProvider),
        ranking = ref.watch(weeklyRankingProvider),
        pending = ref.watch(weeklyScoresProvider).asData?.value;
    final period = week.split('_').last;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.weeklyRanking),
        actions: [
          IconButton(
            tooltip: l.retry,
            onPressed: () {
              ref.invalidate(weeklyRankingProvider);
              ref.read(weeklyScoresProvider.notifier).retry();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Arequipa · ${l.rankingPeriod(int.parse(period.substring(6)), int.parse(period.substring(0, 4)))}',
          ),
          Text(l.rankingPublicName),
          const SizedBox(height: 16),
          if (!enabled)
            Text(l.rankingLocalOnly)
          else ...[
            if (pending?.failed ?? false) Text(l.rankingPending),
            ...ranking.when(
              loading: () => [const LinearProgressIndicator()],
              error: (_, s) => [
                Text(l.rankingUnavailable),
                TextButton(
                  onPressed: () => ref.invalidate(weeklyRankingProvider),
                  child: Text(l.retry),
                ),
              ],
              data: (value) {
                if (value == null) return <Widget>[];
                final rows = <Widget>[];
                if (value.own == null) {
                  rows.add(Text(l.rankingNoScore));
                } else {
                  rows.add(
                    Text(l.rankingOwn(value.position!, value.own!.score)),
                  );
                }
                if (value.top.isEmpty) rows.add(Text(l.rankingEmpty));
                var rank = 0, previous = -1;
                for (final (i, entry) in value.top.indexed) {
                  if (entry.score != previous) {
                    rank = i + 1;
                    previous = entry.score;
                  }
                  rows.add(
                    ListTile(
                      leading: Text('$rank'),
                      title: Text(entry.name),
                      trailing: Text('${entry.score}'),
                    ),
                  );
                }
                return rows;
              },
            ),
            if (ref.watch(authStateProvider).asData?.value == null)
              TextButton(
                onPressed: () => context.push('/acceso?regresar=1'),
                child: Text(l.signIn),
              ),
          ],
        ],
      ),
    );
  }
}
