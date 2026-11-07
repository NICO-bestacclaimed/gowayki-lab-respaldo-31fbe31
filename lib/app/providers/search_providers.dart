import 'dart:convert';
import '../../domain/sync/personal_record.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/place_result.dart';
import '../../domain/models/navigation_search.dart';
import 'app_providers.dart';
import '../sync/personal_data.dart';
import '../library/library_models.dart';

final navigationSearchProvider = FutureProvider.autoDispose
    .family<List<NavigationSearchResult>, String>((ref, query) async {
      return ref.watch(cityPackRepositoryProvider).searchNavigation(query);
    });
final recentPlacesProvider = NotifierProvider<RecentPlaces, List<PlaceResult>>(
  RecentPlaces.new,
);

class RecentPlaces extends Notifier<List<PlaceResult>> {
  static const key = 'navigation.recent_places';
  @override
  List<PlaceResult> build() {
    final syncedState = ref.watch(personalDataProvider);
    final synced = syncedState.isLoading ? null : syncedState.asData?.value;
    if (synced != null) return recentsFrom(synced);
    if (ref.watch(useFirebaseProvider)) return const [];
    try {
      final rows =
          jsonDecode(
                ref
                        .watch(appServicesProvider)
                        .requireValue
                        .localPreferences
                        .getString(key) ??
                    '[]',
              )
              as List;
      return List.unmodifiable(rows.take(30).map(decodePoint));
    } on Object {
      return const [];
    }
  }

  Future<void> _edit(
    Map<String, Object?> Function(PersonalSnapshot) edit,
  ) async {
    final scope = ref.read(personalScopeProvider);
    await ref.read(personalDataProvider.notifier).edit(edit);
    if (ref.mounted && ref.read(personalScopeProvider) == scope) {
      state = recentsFrom(ref.read(personalDataProvider).requireValue);
    }
  }

  Future<void> remember(PlaceResult point) {
    if (point.id == 'current-location') return Future.value();
    return _edit(
      (current) => {
        recentKey(point.id): {
          'point': encodePoint(point),
          'rank': DateTime.now().microsecondsSinceEpoch > current.clock
              ? DateTime.now().microsecondsSinceEpoch
              : current.clock + 1,
        },
      },
    );
  }

  Future<void> remove(String id) => _edit((current) => {recentKey(id): null});
  Future<void> reorder(List<String> ids) => _edit((current) {
    final byId = {for (final point in recentsFrom(current)) point.id: point};
    if (ids.toSet().length != byId.length ||
        ids.length != byId.length ||
        ids.any((id) => !byId.containsKey(id))) {
      throw ArgumentError('Invalid recent order');
    }
    return {
      for (final (index, id) in ids.indexed)
        recentKey(id): {
          'point': encodePoint(byId[id]!),
          'rank': current.clock + ids.length - index,
        },
    };
  });
}
