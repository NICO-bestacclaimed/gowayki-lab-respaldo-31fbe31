import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/location_permission_repository.dart';
import '../../domain/repositories/position_repository.dart';
import '../../infra/location/geolocator_position_repository.dart';
import 'app_providers.dart';
import 'location_ownership_provider.dart';

enum LocationStatus { idle, loading, ready, gpsOff, permission, error }

class ExplorerLocation {
  const ExplorerLocation(this.status, {this.fix});
  final LocationStatus status;
  final PositionFix? fix;
}

final positionRepositoryProvider = Provider<PositionRepository>(
  (ref) => GeolocatorPositionRepository(),
);
final explorerLocationProvider =
    NotifierProvider<ExplorerLocationController, ExplorerLocation>(
      ExplorerLocationController.new,
    );

class ExplorerLocationController extends Notifier<ExplorerLocation> {
  StreamSubscription<PositionFix>? _subscription;
  int _generation = 0;
  bool _active = false;
  @override
  ExplorerLocation build() {
    ref.onDispose(() {
      ++_generation;
      final subscription = _subscription;
      _subscription = null;
      if (subscription != null) {
        unawaited(subscription.cancel().catchError((Object error) {}));
      }
    });
    ref.listen(tripOwnsLocationProvider, (before, owned) {
      if (!owned && _active) {
        unawaited(start(refresh: true));
      }
    });
    return const ExplorerLocation(LocationStatus.idle);
  }

  Future<void> start({bool refresh = false}) async {
    if (_active && !refresh) return;
    _active = true;
    if (ref.read(tripOwnsLocationProvider)) {
      await suspend();
      return;
    }
    final generation = ++_generation;
    bool current() => ref.mounted && _active && generation == _generation;
    final subscription = _subscription;
    _subscription = null;
    try {
      await subscription?.cancel();
    } on Object {
      /* Already stopped by the platform. */
    }
    if (!current()) return;
    state = const ExplorerLocation(LocationStatus.loading);
    try {
      final access = await ref
          .read(locationPermissionRepositoryProvider)
          .check();
      if (!current()) return;
      if (access != LocationAccess.allowed) {
        state = const ExplorerLocation(LocationStatus.permission);
        return;
      }
      final positions = ref.read(positionRepositoryProvider);
      final enabled = await positions.serviceEnabled();
      if (!current()) return;
      if (!enabled) {
        state = const ExplorerLocation(LocationStatus.gpsOff);
        return;
      }
      final fix = await positions.current();
      if (!current()) return;
      state = ExplorerLocation(LocationStatus.ready, fix: fix);
      _subscription = positions.watch().listen(
        (value) {
          if (current()) {
            state = ExplorerLocation(LocationStatus.ready, fix: value);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (current()) state = const ExplorerLocation(LocationStatus.error);
        },
      );
    } on Object {
      if (current()) state = const ExplorerLocation(LocationStatus.error);
    }
  }

  Future<void> suspend() async {
    ++_generation;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    if (ref.mounted) state = const ExplorerLocation(LocationStatus.idle);
  }

  Future<void> stop() async {
    _active = false;
    ++_generation;
    final subscription = _subscription;
    _subscription = null;
    try {
      await subscription?.cancel();
    } on Object {
      /* Already stopped by the platform. */
    }
    if (ref.mounted && !_active) {
      state = const ExplorerLocation(LocationStatus.idle);
    }
  }
}

/// Search can use one fresh sample with an already granted permission.
final currentPositionProvider = FutureProvider.autoDispose<PositionFix?>((
  ref,
) async {
  try {
    if (await ref.read(locationPermissionRepositoryProvider).check() !=
        LocationAccess.allowed) {
      return null;
    }
    final repository = ref.read(positionRepositoryProvider);
    if (!await repository.serviceEnabled()) return null;
    return await repository.current();
  } on Object {
    return null;
  }
});
