import 'dart:async';
import '../sync/personal_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/auth_user.dart';
import '../../core/models/transit_line.dart';
import '../../data/app_services.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/city_pack_repository.dart';
import '../../domain/repositories/city_repository.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../domain/repositories/place_search_repository.dart';
import '../../domain/repositories/preferences_repository.dart';
import '../../domain/repositories/transit_network_repository.dart';
import '../../infra/city_pack/city_pack_installer.dart';
import '../../domain/repositories/location_permission_repository.dart';
import '../../infra/location/geolocator_permission_repository.dart';

final useFirebaseProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('USE_FIREBASE', defaultValue: false),
);
final cityPackInstallerProvider = Provider<CityPackInstaller>(
  (ref) => CityPackInstaller(),
);
final appServicesProvider = FutureProvider<AppServices>((ref) async {
  final firebase = ref.watch(useFirebaseProvider);
  final installer = ref.watch(cityPackInstallerProvider);
  AppServices? owned;
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    if (owned != null) unawaited(owned.close());
  });
  final services = await AppServices.open(
    useFirebase: firebase,
    installer: installer,
  );
  if (disposed) {
    await services.close();
    throw StateError('Inicialización cancelada.');
  }
  owned = services;
  return services;
}, retry: (count, error) => null);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ref.watch(appServicesProvider).requireValue.auth,
);
final cityRepositoryProvider = Provider<CityRepository>(
  (ref) => ref.watch(appServicesProvider).requireValue.cities,
);
final cityPackRepositoryProvider = Provider<CityPackRepository>(
  (ref) => ref.watch(appServicesProvider).requireValue.cityPack,
);
final transitNetworkRepositoryProvider = Provider<TransitNetworkRepository>(
  (ref) => ref.watch(appServicesProvider).requireValue.transit,
);
final placeSearchRepositoryProvider = Provider<PlaceSearchRepository>(
  (ref) => ref.watch(appServicesProvider).requireValue.places,
);
final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => ref.watch(appServicesProvider).requireValue.preferences,
);
final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => ref.watch(appServicesProvider).requireValue.feedback,
);
final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).observeSession(),
);

final cityLinesProvider = FutureProvider<List<TransitLine>>((ref) async {
  final services = await ref.watch(appServicesProvider.future);
  final lines = [...await services.transit.lines()];
  lines.sort((a, b) {
    final name = a.shortName.toLowerCase().compareTo(b.shortName.toLowerCase());
    return name == 0 ? a.id.compareTo(b.id) : name;
  });
  return List.unmodifiable(lines);
});

final favoriteLineIdsProvider = NotifierProvider<FavoriteLineIds, Set<String>>(
  FavoriteLineIds.new,
);

class FavoriteLineIds extends Notifier<Set<String>> {
  static const storageKey = 'favorites.line_ids';
  @override
  Set<String> build() {
    final syncedState = ref.watch(personalDataProvider);
    final synced = syncedState.isLoading ? null : syncedState.asData?.value;
    if (synced != null) return linesFrom(synced);
    if (ref.watch(useFirebaseProvider)) return const {};
    return Set.unmodifiable(
      ref
              .watch(appServicesProvider)
              .requireValue
              .localPreferences
              .getStringList(storageKey) ??
          <String>[],
    );
  }

  Future<void> _edit(String id, bool? selected) async {
    final scope = ref.read(personalScopeProvider);
    await ref
        .read(personalDataProvider.notifier)
        .edit(
          (current) => {
            'line:$id': (selected ?? !linesFrom(current).contains(id))
                ? true
                : null,
          },
        );
    if (ref.mounted && ref.read(personalScopeProvider) == scope) {
      state = linesFrom(ref.read(personalDataProvider).requireValue);
    }
  }

  Future<void> toggle(String id) => _edit(id, null);
  Future<void> remove(String id) => _edit(id, false);
}

final locationPermissionRepositoryProvider =
    Provider<LocationPermissionRepository>(
      (ref) => GeolocatorPermissionRepository(),
    );
