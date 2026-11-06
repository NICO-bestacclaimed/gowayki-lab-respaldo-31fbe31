import 'package:gowayki_lab/shared/widgets/content_state.dart';
import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_providers.dart';

class LinesScreen extends ConsumerWidget {
  const LinesScreen({super.key, this.favoritesOnly = false});
  final bool favoritesOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteLineIdsProvider);
    final lines = ref.watch(cityLinesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          favoritesOnly ? context.l10n.favorites : context.l10n.routes,
        ),
      ),
      body: lines.when(
        loading: () => const ContentSkeleton(),
        error: (error, stack) => ContentState(
          kind: ContentStateKind.error,
          message: context.l10n.linesError,
          onAction: () => ref.invalidate(cityLinesProvider),
        ),
        data: (all) {
          final visible = favoritesOnly
              ? all.where((line) => favorites.contains(line.id)).toList()
              : all;
          if (visible.isEmpty) {
            return ContentState(
              kind: ContentStateKind.empty,
              message: favoritesOnly
                  ? context.l10n.favoritesEmpty
                  : context.l10n.linesEmpty,
            );
          }
          return ListView.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final line = visible[index];
              final selected = favorites.contains(line.id);
              return ListTile(
                key: ValueKey('line-${line.id}'),
                leading: const Icon(Icons.directions_bus_outlined),
                title: Text(line.shortName),
                subtitle: Text(
                  line.directions
                      .map((d) => d.headsign)
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                ),
                trailing: IconButton(
                  key: ValueKey('favorite-${line.id}'),
                  tooltip: selected
                      ? context.l10n.removeFavorite
                      : context.l10n.addFavorite,
                  icon: Icon(selected ? Icons.star : Icons.star_border),
                  onPressed: () async {
                    try {
                      await ref
                          .read(favoriteLineIdsProvider.notifier)
                          .toggle(line.id);
                    } on Object {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.saveFailed)),
                        );
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
