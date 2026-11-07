import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/place_result.dart';
import '../../../../core/models/transit_line.dart';
import '../../../../domain/models/navigation_search.dart';
import '../../../../shared/l10n/l10n.dart';
import '../../../../shared/widgets/content_state.dart';
import '../../../library/local_library.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/map_providers.dart';
import '../../../providers/search_providers.dart';
import '../../planner/presentation/widgets/itinerary_card.dart';
import '../../search/presentation/search_screen.dart';

class _LibraryRow {
  const _LibraryRow(this.id, {this.item, this.line});
  final String id;
  final LibraryItem? item;
  final TransitLine? line;
}

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});
  void _error(BuildContext context) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
    }
  }

  Future<void> _configure(
    BuildContext context,
    WidgetRef ref,
    LibraryKind kind,
  ) async {
    final point = await context.push<PlaceResult>(
      '/buscar',
      extra: const SearchArguments(pickSingle: true),
    );
    if (!context.mounted || point == null) return;
    try {
      await ref.read(localLibraryProvider.notifier).setSpecial(kind, point);
    } on Object {
      if (context.mounted) _error(context);
    }
  }

  Future<void> _openPoint(BuildContext context, PlaceResult point) async {
    final pair = await context.push<JourneyEndpoints>(
      '/buscar',
      extra: SearchArguments(destination: point),
    );
    if (context.mounted && pair != null) {
      await context.push('/planificar', extra: pair);
    }
  }

  Future<bool> _remove(
    BuildContext context,
    WidgetRef ref,
    _LibraryRow row,
  ) async {
    try {
      if (row.line != null) {
        await ref.read(favoriteLineIdsProvider.notifier).remove(row.line!.id);
      } else {
        await ref.read(localLibraryProvider.notifier).remove(row.id);
      }
      return true;
    } on Object {
      if (context.mounted) _error(context);
      return false;
    }
  }

  Widget _saved(
    BuildContext context,
    WidgetRef ref,
    LocalLibrary library,
    List<TransitLine> all,
    Set<String> ids,
  ) {
    final l = context.l10n;
    final rows = [
      for (final item in library.items) _LibraryRow(item.id, item: item),
      for (final line in all)
        if (ids.contains(line.id)) _LibraryRow('line:${line.id}', line: line),
    ];
    final ranks = {for (final (i, id) in library.order.indexed) id: i};
    final initial = {for (final (i, row) in rows.indexed) row.id: i};
    rows.sort(
      (a, b) => (ranks[a.id] ?? library.order.length + initial[a.id]!)
          .compareTo(ranks[b.id] ?? library.order.length + initial[b.id]!),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('library.configure.home'),
                onPressed: () => _configure(context, ref, LibraryKind.home),
                icon: const Icon(Icons.home_outlined),
                label: Text(
                  library.special(LibraryKind.home) == null
                      ? l.configureHome
                      : '${l.edit} ${l.home}',
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('library.configure.work'),
                onPressed: () => _configure(context, ref, LibraryKind.work),
                icon: const Icon(Icons.work_outline),
                label: Text(
                  library.special(LibraryKind.work) == null
                      ? l.configureWork
                      : '${l.edit} ${l.work}',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? ContentState(
                  kind: ContentStateKind.empty,
                  message: l.favoritesEmpty,
                )
              : ReorderableListView(
                  onReorderItem: (oldIndex, newIndex) async {
                    final order = rows.map((row) => row.id).toList();
                    final id = order.removeAt(oldIndex);
                    order.insert(newIndex, id);
                    try {
                      await ref
                          .read(localLibraryProvider.notifier)
                          .reorder(order);
                    } on Object {
                      if (context.mounted) _error(context);
                    }
                  },
                  children: [
                    for (final row in rows)
                      Dismissible(
                        key: ValueKey('library.${row.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Theme.of(context).colorScheme.errorContainer,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.all(20),
                          child: const Icon(Icons.delete_outline),
                        ),
                        confirmDismiss: (_) => _remove(context, ref, row),
                        child: _tile(context, ref, row),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, _LibraryRow row) {
    final l = context.l10n, line = row.line;
    if (line != null) {
      return ListTile(
        key: ValueKey('line-${line.id}'),
        leading: LineAvatar(name: line.shortName, color: line.color),
        title: Text(line.shortName),
        subtitle: Text(line.directions.map((d) => d.headsign).join(' · ')),
        onTap: () => context.push('/linea/${Uri.encodeComponent(line.id)}'),
        trailing: IconButton(
          key: ValueKey('favorite-${line.id}'),
          tooltip: l.removeFavorite,
          onPressed: () => _remove(context, ref, row),
          icon: const Icon(Icons.star),
        ),
      );
    }
    final item = row.item!;
    final icon = switch (item.kind) {
      LibraryKind.home => Icons.home,
      LibraryKind.work => Icons.work,
      LibraryKind.place => Icons.place,
      LibraryKind.stop => Icons.directions_bus,
      LibraryKind.trip => Icons.route,
    };
    final label = switch (item.kind) {
      LibraryKind.home => l.home,
      LibraryKind.work => l.work,
      LibraryKind.place => l.savedPlaces,
      LibraryKind.stop => l.favoriteStops,
      LibraryKind.trip => l.savedTrips,
    };
    return ListTile(
      leading: Icon(icon),
      title: Text(item.label),
      subtitle: Text(label),
      onTap: () {
        if (item.trip != null) {
          context.push('/planificar', extra: item.trip);
        } else if (item.kind == LibraryKind.stop) {
          context.push('/paradero/${Uri.encodeComponent(item.point!.id)}');
        } else {
          _openPoint(context, item.point!);
        }
      },
      trailing: IconButton(
        tooltip: l.delete,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _remove(context, ref, row),
      ),
    );
  }

  Widget _recent(BuildContext context, WidgetRef ref) {
    final l = context.l10n,
        points = ref.watch(recentPlacesProvider),
        library = ref.watch(localLibraryProvider);
    if (points.isEmpty) return const ContentState(kind: ContentStateKind.empty);
    final map = ref.watch(transitMapDataProvider);
    String bookmarkId(PlaceResult point) =>
        '${map.asData?.value.stops.containsKey(point.id) == true ? 'stop' : 'place'}:${point.id}';
    return ReorderableListView(
      onReorderItem: (oldIndex, newIndex) async {
        final order = points.map((p) => p.id).toList();
        final id = order.removeAt(oldIndex);
        order.insert(newIndex, id);
        try {
          await ref.read(recentPlacesProvider.notifier).reorder(order);
        } on Object {
          if (context.mounted) _error(context);
        }
      },
      children: [
        for (final point in points)
          Dismissible(
            key: ValueKey('recent.${point.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Theme.of(context).colorScheme.errorContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.all(20),
              child: const Icon(Icons.delete_outline),
            ),
            confirmDismiss: (_) async {
              try {
                await ref.read(recentPlacesProvider.notifier).remove(point.id);
                return true;
              } on Object {
                if (context.mounted) _error(context);
                return false;
              }
            },
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(point.name),
              subtitle: point.address.isEmpty ? null : Text(point.address),
              onTap: () => _openPoint(context, point),
              trailing: IconButton(
                tooltip: l.addFavorite,
                icon: Icon(
                  library.asData?.value.contains(bookmarkId(point)) == true
                      ? Icons.star
                      : Icons.star_border,
                ),
                onPressed: !library.hasValue || !map.hasValue
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(localLibraryProvider.notifier)
                              .toggle(
                                LibraryItem(
                                  id: bookmarkId(point),
                                  kind:
                                      map.asData?.value.stops.containsKey(
                                            point.id,
                                          ) ==
                                          true
                                      ? LibraryKind.stop
                                      : LibraryKind.place,
                                  label: point.name,
                                  point: point,
                                ),
                              );
                        } on Object {
                          if (context.mounted) _error(context);
                        }
                      },
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n,
        library = ref.watch(localLibraryProvider),
        lines = ref.watch(cityLinesProvider),
        favorites = ref.watch(favoriteLineIdsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.favorites),
          bottom: TabBar(
            tabs: [
              Tab(text: l.saved),
              Tab(text: l.recent),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            library.when(
              loading: () => const ContentSkeleton(),
              error: (e, s) => ContentState(
                kind: ContentStateKind.error,
                onAction: () => ref.invalidate(localLibraryProvider),
              ),
              data: (data) => lines.when(
                loading: () => const ContentSkeleton(),
                error: (e, s) => ContentState(
                  kind: ContentStateKind.error,
                  onAction: () => ref.invalidate(cityLinesProvider),
                ),
                data: (all) => _saved(context, ref, data, all, favorites),
              ),
            ),
            _recent(context, ref),
          ],
        ),
      ),
    );
  }
}
