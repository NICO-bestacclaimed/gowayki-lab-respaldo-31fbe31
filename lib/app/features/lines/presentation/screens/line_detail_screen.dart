import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/models/transit_line.dart';
import '../../../../../shared/l10n/l10n.dart';
import '../../../../../shared/widgets/content_state.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/map_renderer_provider.dart';
import '../../../../providers/planner_providers.dart';
import '../../../../providers/sharing_providers.dart';
import '../../../../providers/transit_details_providers.dart';
import '../../../explorer/presentation/widgets/explorer_map.dart';
import '../../../planner/presentation/widgets/itinerary_card.dart';

class LineDetailScreen extends ConsumerStatefulWidget {
  const LineDetailScreen({super.key, required this.lineId});
  final String lineId;
  @override
  ConsumerState<LineDetailScreen> createState() => _LineDetailState();
}

class _LineDetailState extends ConsumerState<LineDetailScreen> {
  String? _pattern;
  Timer? _clock;
  bool _sharing = false;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _favorite() async {
    try {
      await ref.read(favoriteLineIdsProvider.notifier).toggle(widget.lineId);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
      }
    }
  }

  Future<void> _share(LineDetailsData data) async {
    final l = context.l10n,
        headway = data.settings.frequencyAt(ref.read(appClockProvider)());
    final text = [
      'GoWayki · ${l.line}: ${data.line.shortName}',
      for (final pattern in data.patterns)
        '${pattern.direction == 'ida' ? l.outbound : l.inbound}: ${pattern.headsign}',
      headway == null ? l.noService : l.frequencyApprox(headway.round()),
      if (data.fare != null) l.fareAmount(data.fare!.amount.toStringAsFixed(2)),
      l.estimatedTimes,
    ].join('\n');
    final box = context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      await ref.read(textSharingProvider).share(text, origin: origin);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.genericError)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, favorites = ref.watch(favoriteLineIdsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.line),
        actions: [
          IconButton(
            key: const ValueKey('lineDetail.favorite'),
            tooltip: favorites.contains(widget.lineId)
                ? l.removeFavorite
                : l.addFavorite,
            onPressed: _favorite,
            icon: Icon(
              favorites.contains(widget.lineId)
                  ? Icons.star
                  : Icons.star_border,
            ),
          ),
        ],
      ),
      body: ref
          .watch(lineDetailsProvider(widget.lineId))
          .when(
            loading: () => const ContentSkeleton(),
            error: (e, s) => ContentState(
              kind: ContentStateKind.error,
              onAction: () =>
                  ref.invalidate(lineDetailsProvider(widget.lineId)),
            ),
            data: (data) {
              if (data.patterns.isEmpty) {
                return const ContentState(kind: ContentStateKind.noResults);
              }
              final pattern =
                  data.patterns.where((p) => p.id == _pattern).firstOrNull ??
                  data.patterns.first;
              final headway = data.settings.frequencyAt(
                ref.read(appClockProvider)(),
              );
              final visits = data.visits[pattern.id] ?? const [];
              return ListView(
                children: [
                  ListTile(
                    leading: LineAvatar(
                      name: data.line.shortName,
                      color: data.line.color,
                    ),
                    title: Text(data.line.shortName),
                    subtitle: Text(
                      data.patterns
                          .map(
                            (p) =>
                                '${p.direction == 'ida' ? l.outbound : l.inbound}: ${p.headsign}',
                          )
                          .join('\n'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('lineDetail.direction.${pattern.id}'),
                      initialValue: pattern.id,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: InputDecoration(
                        labelText: l.directionSelector,
                      ),
                      items: [
                        for (final p in data.patterns)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              '${p.direction == 'ida' ? l.outbound : l.inbound}: ${p.headsign}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) => setState(() => _pattern = id),
                    ),
                  ),
                  SizedBox(
                    height: 260,
                    child: ref.watch(explorerMapRendererProvider)(
                      ExplorerMap(
                        focusedLineId: widget.lineId,
                        focusedDirection: pattern.direction == 'ida'
                            ? TransitDirectionKind.ida
                            : TransitDirectionKind.vuelta,
                        onStopTap: (stop) => context.push(
                          '/paradero/${Uri.encodeComponent(stop.stop.id)}',
                        ),
                        onRouteTap: (route) {
                          final match = data.patterns
                              .where(
                                (p) => p.routeId == route.direction.routeId,
                              )
                              .firstOrNull;
                          if (match != null) {
                            setState(() => _pattern = match.id);
                          }
                        },
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text(
                      headway == null
                          ? l.noService
                          : l.frequencyApprox(headway.round()),
                    ),
                    subtitle: Text(
                      data.fare == null
                          ? l.estimatedTimes
                          : l.fareAmount(data.fare!.amount.toStringAsFixed(2)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed: _sharing ? null : () => _share(data),
                      icon: const Icon(Icons.share),
                      label: Text(l.share),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l.stops,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final visit in visits)
                    ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text(
                          '${visit.sequence}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      title: Text(visit.stop.name),
                      subtitle: visit.stop.needsReview
                          ? Text(l.estimatedName)
                          : null,
                      onTap: () => context.push(
                        '/paradero/${Uri.encodeComponent(visit.stop.id)}',
                      ),
                    ),
                ],
              );
            },
          ),
    );
  }
}
