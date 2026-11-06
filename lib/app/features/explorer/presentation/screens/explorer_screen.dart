import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/place_result.dart';
import '../../../../../core/models/transit_line.dart';
import '../../../../providers/app_providers.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../common/ui/layouts/map_layout.dart';
import '../widgets/combis_sheet.dart';
import '../widgets/explorer_map.dart';

/// Explorador: mapa a pantalla completa (interfaz tipo Gowayki GO).
class ExplorerScreen extends ConsumerStatefulWidget {
  const ExplorerScreen({
    super.key,
    required this.onPlanTrip,
    required this.onOpenMenu,
  });

  final void Function(PlaceResult destination) onPlanTrip;
  final VoidCallback onOpenMenu;

  @override
  ConsumerState<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends ConsumerState<ExplorerScreen> {
  final _mapKey = GlobalKey<ExplorerMapState>();
  final _query = TextEditingController();
  final _focus = FocusNode();

  List<PlaceResult> _results = [];
  PlaceResult? _selected;
  TransitLine? _focusedLine;
  TransitDirectionKind? _focusedDirection;
  bool _searching = false;
  bool _showTransit = true;
  bool _searchOpen = false;

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _onQuery(String value) async {
    setState(() {
      _searching = true;
      _searchOpen = true;
    });
    final results = await ref.read(placeSearchRepositoryProvider).search(value);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _select(PlaceResult place) {
    setState(() {
      _selected = place;
      _focusedLine = null;
      _focusedDirection = null;
      _searchOpen = false;
      _focus.unfocus();
    });
    _mapKey.currentState?.flyTo(lat: place.latitude, lng: place.longitude);
  }

  Future<void> _openCombis() async {
    await CombisSheet.open(
      context,
      onSelected: (line) {
        setState(() {
          _focusedLine = line;
          _focusedDirection = null; // ambos
          _selected = null;
          _searchOpen = false;
          _showTransit = true;
        });
      },
    );
  }

  Color _lineColor(String hex) {
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h, radix: 16) ?? 0xF05709;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final sheetH = _focusedLine != null
        ? 188.0 + bottomPad
        : _selected != null
        ? 168.0 + bottomPad
        : (_searchOpen ? 280.0 + bottomPad : 0.0);

    return MapLayout(
      map: ExplorerMap(
        key: _mapKey,
        showTransit: _showTransit,
        focusedLineId: _focusedLine?.id,
        focusedDirection: _focusedDirection,
      ),
      overlays: [
        MapControls(
          bottomInset: sheetH,
          topLeft: MapRoundButton(
            icon: Icons.menu_rounded,
            onPressed: widget.onOpenMenu,
          ),
          topRight: _SearchField(
            controller: _query,
            focusNode: _focus,
            onChanged: _onQuery,
            onClear: () {
              _query.clear();
              setState(() {
                _results = [];
                _searchOpen = false;
                _selected = null;
              });
            },
          ),
          centerRight: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MapRoundButton(
                icon: Icons.directions_bus_filled_rounded,
                selected: _focusedLine != null || _showTransit,
                onPressed: _openCombis,
              ),
              const SizedBox(height: AppSpacing.sm),
              MapRoundButton(
                icon: Icons.layers_rounded,
                selected: _showTransit && _focusedLine == null,
                onPressed: () => setState(() {
                  _showTransit = !_showTransit;
                  if (_showTransit) {
                    _focusedLine = null;
                    _focusedDirection = null;
                  }
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              MapRoundButton(
                icon: Icons.my_location_rounded,
                onPressed: () =>
                    _mapKey.currentState?.flyTo(lat: -16.3989, lng: -71.5369),
              ),
            ],
          ),
        ),
      ],
      sheet: sheetH == 0
          ? null
          : Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: SizedBox(
                  height: sheetH,
                  width: double.infinity,
                  child: _focusedLine != null
                      ? _CombiPreview(
                          line: _focusedLine!,
                          color: _lineColor(_focusedLine!.color),
                          selected: _focusedDirection,
                          onSelectDirection: (kind) => setState(() {
                            // Tocar de nuevo el activo = volver a ambos.
                            _focusedDirection = _focusedDirection == kind
                                ? null
                                : kind;
                          }),
                          onClose: () => setState(() {
                            _focusedLine = null;
                            _focusedDirection = null;
                          }),
                          onShowAll: () => setState(() {
                            _focusedLine = null;
                            _focusedDirection = null;
                            _showTransit = true;
                          }),
                        )
                      : _selected != null
                      ? _PlacePreview(
                          place: _selected!,
                          onClose: () => setState(() => _selected = null),
                          onDirections: () => widget.onPlanTrip(_selected!),
                        )
                      : _SearchResults(
                          searching: _searching,
                          results: _results,
                          onTap: _select,
                        ),
                ),
              ),
            ),
    );
  }
}

class _CombiPreview extends StatelessWidget {
  const _CombiPreview({
    required this.line,
    required this.color,
    required this.selected,
    required this.onSelectDirection,
    required this.onClose,
    required this.onShowAll,
  });

  final TransitLine line;
  final Color color;
  final TransitDirectionKind? selected;
  final ValueChanged<TransitDirectionKind> onSelectDirection;
  final VoidCallback onClose;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final canChoose = line.directions.length > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                foregroundColor: Colors.white,
                child: Text(
                  line.shortName.isEmpty
                      ? '?'
                      : (line.shortName.length > 3
                            ? line.shortName.substring(0, 3)
                            : line.shortName),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  line.shortName.isEmpty ? context.l10n.line : line.shortName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onShowAll,
                child: Text(context.l10n.allDirections),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, d) in line.directions.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _DirectionChip(
                    direction: d,
                    active: selected == null || selected == d.kind,
                    onTap: canChoose ? () => onSelectDirection(d.kind) : null,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({
    required this.direction,
    required this.active,
    this.onTap,
  });

  final TransitDirection direction;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ida = direction.kind == TransitDirectionKind.ida;
    final color = ida ? AppColors.transitIda : AppColors.transitVuelta;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: active ? 1 : 0.45,
      child: Material(
        color: active
            ? color.withValues(alpha: 0.16)
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: active ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ida ? context.l10n.outbound : context.l10n.inbound,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  context.l10n.towards(direction.headsign),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width - 88,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: context.l10n.whereTo,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: onClear,
                    ),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.searching,
    required this.results,
    required this.onTap,
  });

  final bool searching;
  final List<PlaceResult> results;
  final ValueChanged<PlaceResult> onTap;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return Center(
        child: Text(
          context.l10n.searchExamples,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      itemCount: results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = results[i];
        return ListTile(
          leading: const Icon(Icons.place_outlined, color: AppColors.primary),
          title: Text(
            p.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(p.address),
          trailing: const Icon(
            Icons.directions_rounded,
            color: AppColors.primary,
          ),
          onTap: () => onTap(p),
        );
      },
    );
  }
}

class _PlacePreview extends StatelessWidget {
  const _PlacePreview({
    required this.place,
    required this.onClose,
    required this.onDirections,
  });

  final PlaceResult place;
  final VoidCallback onClose;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  place.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
            ],
          ),
          Text(
            place.address,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onDirections,
            icon: const Icon(Icons.directions_rounded),
            label: Text(context.l10n.directions),
          ),
        ],
      ),
    );
  }
}
