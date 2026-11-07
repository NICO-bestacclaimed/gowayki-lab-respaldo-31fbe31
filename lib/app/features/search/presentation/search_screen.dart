import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/place_result.dart';
import '../../../../domain/models/navigation_search.dart';
import '../../../../shared/l10n/l10n.dart';
import '../../../../shared/widgets/content_state.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/map_providers.dart';
import '../../../providers/search_providers.dart';

class SearchArguments {
  const SearchArguments({
    this.origin,
    this.destination,
    this.editOrigin = false,
    this.currentLocation,
  });
  final PlaceResult? origin, destination, currentLocation;
  final bool editOrigin;
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.arguments = const SearchArguments()});
  final SearchArguments arguments;
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _originText, _destinationText;
  PlaceResult? _origin, _destination;
  late bool _editOrigin;
  String _query = '';
  String? _line;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _origin = widget.arguments.origin ?? widget.arguments.currentLocation;
    _destination = widget.arguments.destination;
    _editOrigin = widget.arguments.editOrigin;
    _originText = TextEditingController(text: _origin?.name ?? '');
    _destinationText = TextEditingController(text: _destination?.name ?? '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _originText.dispose();
    _destinationText.dispose();
    super.dispose();
  }

  void _changed(String value, bool origin) {
    _debounce?.cancel();
    setState(() {
      _editOrigin = origin;
      _line = null;
      if (origin) {
        _origin = null;
      } else {
        _destination = null;
      }
    });
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _select(PlaceResult point) async {
    _debounce?.cancel();
    setState(() {
      if (_editOrigin) {
        _origin = point;
        _originText.text = point.name;
        _editOrigin = false;
      } else {
        _destination = point;
        _destinationText.text = point.name;
      }
      _query = '';
      _line = null;
    });
    FocusScope.of(context).unfocus();
    try {
      await ref.read(recentPlacesProvider.notifier).remember(point);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
      }
    }
  }

  void _swap() {
    _debounce?.cancel();
    setState(() {
      final point = _origin;
      _origin = _destination;
      _destination = point;
      final text = _originText.text;
      _originText.text = _destinationText.text;
      _destinationText.text = text;
      _editOrigin = !_editOrigin;
      _query = '';
      _line = null;
    });
  }

  Widget _field(bool origin) => TextField(
    key: ValueKey(origin ? 'search.origin' : 'search.destination'),
    controller: origin ? _originText : _destinationText,
    maxLength: 512,
    decoration: InputDecoration(
      counterText: '',
      labelText: origin ? context.l10n.origin : context.l10n.destination,
      prefixIcon: Icon(origin ? Icons.trip_origin : Icons.place_outlined),
    ),
    onTap: () {
      _debounce?.cancel();
      setState(() {
        _editOrigin = origin;
        _query = '';
        _line = null;
      });
    },
    onChanged: (text) => _changed(text, origin),
  );
  String _group(NavigationSearchGroup group) => switch (group) {
    NavigationSearchGroup.place => context.l10n.places,
    NavigationSearchGroup.stop => context.l10n.stops,
    NavigationSearchGroup.line => context.l10n.routes,
    NavigationSearchGroup.street => context.l10n.streets,
  };
  Widget _pointTile(PlaceResult point, {bool review = false}) => ListTile(
    title: Text(point.name),
    subtitle: review
        ? Text(context.l10n.estimatedName)
        : point.address.isEmpty
        ? null
        : Text(point.address),
    leading: const Icon(Icons.place_outlined),
    onTap: () => _select(point),
  );
  Widget _body() {
    final map = ref.watch(transitMapDataProvider);
    if (_line != null) {
      return map.when(
        loading: () => const ContentSkeleton(),
        error: (e, s) => ContentState(
          kind: ContentStateKind.error,
          onAction: () => ref.invalidate(transitMapDataProvider),
        ),
        data: (data) {
          final stops =
              data.stops.values
                  .where(
                    (s) => s.services.any((service) => service.lineId == _line),
                  )
                  .toList()
                ..sort((a, b) => a.stop.name.compareTo(b.stop.name));
          return ListView(
            children: [
              ListTile(
                title: Text(context.l10n.chooseStop),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _line = null),
                ),
              ),
              for (final entry in stops)
                _pointTile(
                  PlaceResult(
                    id: entry.stop.id,
                    name: entry.stop.name,
                    address: '',
                    latitude: entry.stop.latitude,
                    longitude: entry.stop.longitude,
                  ),
                  review: entry.stop.needsReview,
                ),
            ],
          );
        },
      );
    }
    if (_query.isEmpty) {
      final recent = ref.watch(recentPlacesProvider);
      final favorites = ref.watch(favoriteLineIdsProvider);
      final lines =
          map.asData?.value.lines
              .where((l) => favorites.contains(l.id))
              .toList() ??
          [];
      return ListView(
        children: [
          if (widget.arguments.currentLocation != null)
            ListTile(
              key: const ValueKey('search.myLocation'),
              leading: const Icon(Icons.my_location),
              title: Text(context.l10n.myLocation),
              onTap: () => _select(widget.arguments.currentLocation!),
            ),
          if (lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.favorites),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final line in lines)
                        ActionChip(
                          label: Text(line.shortName),
                          onPressed: () => setState(() => _line = line.id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (recent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.recent),
            ),
          for (final point in recent) _pointTile(point),
          if (recent.isEmpty && lines.isEmpty)
            const ContentState(kind: ContentStateKind.empty),
        ],
      );
    }
    return ref
        .watch(navigationSearchProvider(_query))
        .when(
          loading: () => const ContentSkeleton(),
          error: (e, s) => ContentState(
            kind: ContentStateKind.error,
            onAction: () => ref.invalidate(navigationSearchProvider(_query)),
          ),
          data: (results) {
            if (results.isEmpty) {
              return const ContentState(kind: ContentStateKind.noResults);
            }
            return ListView(
              children: [
                for (final group in NavigationSearchGroup.values) ...[
                  if (results.any((r) => r.group == group))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        _group(group),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  for (final result in results.where((r) => r.group == group))
                    if (result.point != null)
                      _pointTile(result.point!, review: result.needsReview)
                    else
                      ListTile(
                        leading: const Icon(Icons.directions_bus),
                        title: Text(result.name),
                        subtitle: Text(
                          result.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => setState(() => _line = result.id),
                      ),
                ],
              ],
            );
          },
        );
  }

  Widget _form() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  _field(true),
                  const SizedBox(height: 12),
                  _field(false),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('search.swap'),
              tooltip: context.l10n.swapPoints,
              onPressed: _swap,
              icon: const Icon(Icons.swap_vert),
            ),
          ],
        ),
      ),
      Expanded(child: _body()),
      Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          key: const ValueKey('search.usePoints'),
          onPressed: _origin == null || _destination == null
              ? null
              : () => Navigator.of(context).pop(
                  JourneyEndpoints(
                    origin: _origin!,
                    destination: _destination!,
                  ),
                ),
          child: Text(context.l10n.usePoints),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.choosePoints)),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minimum = 320 + MediaQuery.textScalerOf(context).scale(80);
          if (constraints.maxHeight >= minimum) return _form();
          return SingleChildScrollView(
            primary: false,
            child: SizedBox(height: minimum, child: _form()),
          );
        },
      ),
    ),
  );
}
