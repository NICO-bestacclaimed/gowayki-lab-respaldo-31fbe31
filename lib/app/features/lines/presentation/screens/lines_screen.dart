import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../domain/repositories/location_permission_repository.dart';
import '../../../../../shared/l10n/l10n.dart';
import '../../../../../shared/widgets/content_state.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/location_providers.dart';
import '../../../../providers/map_providers.dart';
import '../../../../settings/app_settings.dart';
import '../../../explorer/map/nearby_stops.dart';
import '../../../explorer/map/transit_map_data.dart';
import '../../../planner/presentation/widgets/itinerary_card.dart';

String foldSearch(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[áàäâ]'), 'a')
    .replaceAll(RegExp('[éèëê]'), 'e')
    .replaceAll(RegExp('[íìïî]'), 'i')
    .replaceAll(RegExp('[óòöô]'), 'o')
    .replaceAll(RegExp('[úùüû]'), 'u')
    .replaceAll('ñ', 'n');

class LinesScreen extends ConsumerStatefulWidget {
  const LinesScreen({super.key, this.favoritesOnly = false});
  final bool favoritesOnly;
  @override
  ConsumerState<LinesScreen> createState() => _LinesState();
}

class _LinesState extends ConsumerState<LinesScreen> {
  String _query = '';
  bool _near = false, _busy = false;
  Set<String> _nearIds = {};
  Future<void> _toggleNear() async {
    if (_near) {
      setState(() => _near = false);
      return;
    }
    setState(() => _busy = true);
    try {
      final permission = await ref
          .read(locationPermissionRepositoryProvider)
          .check();
      if (!mounted) return;
      if (permission != LocationAccess.allowed) {
        await context.push('/ubicacion');
        return;
      }
      final repository = ref.read(positionRepositoryProvider);
      if (!await repository.serviceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.gpsOffBody),
              action: SnackBarAction(
                label: context.l10n.openSettings,
                onPressed: () => repository.openServiceSettings(),
              ),
            ),
          );
        }
        return;
      }
      final fix = await repository.current();
      final data =
          ref.read(transitMapDataProvider).asData?.value ??
          await ref.read<Future<TransitMapData>>(transitMapDataProvider.future);
      if (!mounted) return;
      final radius =
          ref
              .read(appSettingsProvider)
              .asData
              ?.value
              .maxAccessMeters
              ?.toDouble() ??
          800;
      final nearby = nearbyStops(
        data.stops.values,
        fix.point,
        limitMeters: radius,
        limit: data.stops.length,
      );
      setState(() {
        _nearIds = nearby
            .expand((stop) => stop.entry.services.map((s) => s.lineId))
            .toSet();
        _near = true;
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n,
        favorites = ref.watch(favoriteLineIdsProvider),
        lines = ref.watch(cityLinesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.favoritesOnly ? l.favorites : l.routes),
      ),
      body: Column(
        children: [
          if (!widget.favoritesOnly)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('lines.search'),
                    decoration: InputDecoration(
                      hintText: l.searchLine,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        setState(() => _query = foldSearch(value.trim())),
                  ),
                  const SizedBox(height: 8),
                  FilterChip(
                    label: Text(_busy ? l.waitMoment : l.nearMe),
                    selected: _near,
                    onSelected: _busy ? null : (_) => _toggleNear(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: lines.when(
              loading: () => const ContentSkeleton(),
              error: (e, s) => ContentState(
                kind: ContentStateKind.error,
                message: l.linesError,
                onAction: () => ref.invalidate(cityLinesProvider),
              ),
              data: (all) {
                final visible = all
                    .where(
                      (line) =>
                          (!widget.favoritesOnly ||
                              favorites.contains(line.id)) &&
                          (!_near || _nearIds.contains(line.id)) &&
                          (_query.isEmpty ||
                              foldSearch(
                                '${line.shortName} ${line.directions.map((d) => d.headsign).join(' ')}',
                              ).contains(_query)),
                    )
                    .toList();
                if (visible.isEmpty) {
                  return ContentState(
                    kind: ContentStateKind.empty,
                    message: widget.favoritesOnly
                        ? l.favoritesEmpty
                        : _query.isNotEmpty || _near
                        ? l.noResults
                        : l.linesEmpty,
                  );
                }
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final line = visible[index],
                        selected = favorites.contains(line.id);
                    return ListTile(
                      key: ValueKey('line-${line.id}'),
                      leading: LineAvatar(
                        name: line.shortName,
                        color: line.color,
                      ),
                      title: Text(line.shortName),
                      subtitle: Text(
                        line.directions
                            .map((d) => d.headsign)
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                      ),
                      onTap: () => context.push(
                        '/linea/${Uri.encodeComponent(line.id)}',
                      ),
                      trailing: IconButton(
                        key: ValueKey('favorite-${line.id}'),
                        tooltip: selected ? l.removeFavorite : l.addFavorite,
                        icon: Icon(selected ? Icons.star : Icons.star_border),
                        onPressed: () async {
                          try {
                            await ref
                                .read(favoriteLineIdsProvider.notifier)
                                .toggle(line.id);
                          } on Object {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.l10n.saveFailed),
                                ),
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
          ),
        ],
      ),
    );
  }
}
