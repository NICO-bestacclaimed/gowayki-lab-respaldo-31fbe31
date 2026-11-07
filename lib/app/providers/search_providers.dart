import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/place_result.dart';
import '../../domain/models/navigation_search.dart';
import 'app_providers.dart';

final navigationSearchProvider = FutureProvider.autoDispose
    .family<List<NavigationSearchResult>, String>((ref, query) async {
      return ref.watch(cityPackRepositoryProvider).searchNavigation(query);
    });
final recentPlacesProvider = NotifierProvider<RecentPlaces, List<PlaceResult>>(
  RecentPlaces.new,
);

class RecentPlaces extends Notifier<List<PlaceResult>> {
  static const key = 'navigation.recent_places';
  Future<void>? _pending;
  @override
  List<PlaceResult> build() {
    try {
      final text = ref
          .watch(appServicesProvider)
          .requireValue
          .localPreferences
          .getString(key);
      final rows = jsonDecode(text ?? '[]') as List;
      final values = <PlaceResult>[];
      final ids = <String>{};
      for (final row in rows.take(30)) {
        final lat = (row['lat'] as num).toDouble(),
            lon = (row['lon'] as num).toDouble();
        if (!lat.isFinite ||
            !lon.isFinite ||
            lat.abs() > 90 ||
            lon.abs() > 180) {
          continue;
        }
        final id = row['id'] as String;
        if (ids.add(id)) {
          values.add(
            PlaceResult(
              id: id,
              name: row['name'] as String,
              address: row['address'] as String,
              latitude: lat,
              longitude: lon,
            ),
          );
        }
      }
      return List.unmodifiable(values);
    } on Object {
      return const [];
    }
  }

  Future<void> _change(
    List<PlaceResult> Function(List<PlaceResult>) change,
  ) async {
    final previous = _pending, turn = Completer<void>();
    _pending = turn.future;
    if (previous != null) await previous;
    try {
      if (!ref.mounted) return;
      final next = change(state);
      final prefs = ref.read(appServicesProvider).requireValue.localPreferences;
      if (!await prefs.setString(
        key,
        jsonEncode(
          next
              .map(
                (p) => {
                  'id': p.id,
                  'name': p.name,
                  'address': p.address,
                  'lat': p.latitude,
                  'lon': p.longitude,
                },
              )
              .toList(),
        ),
      )) {
        throw StateError('Not saved');
      }
      if (ref.mounted) state = List.unmodifiable(next);
    } finally {
      turn.complete();
    }
  }

  Future<void> remember(PlaceResult point) {
    if (point.id == 'current-location') return Future.value();
    return _change(
      (current) =>
          [point, ...current.where((p) => p.id != point.id)].take(30).toList(),
    );
  }

  Future<void> remove(String id) =>
      _change((current) => current.where((p) => p.id != id).toList());
  Future<void> reorder(List<String> ids) => _change((current) {
    final byId = {for (final point in current) point.id: point};
    if (ids.toSet().length != current.length ||
        ids.any((id) => !byId.containsKey(id))) {
      throw ArgumentError('Invalid recent order');
    }
    return ids.map((id) => byId[id]!).toList();
  });
}
