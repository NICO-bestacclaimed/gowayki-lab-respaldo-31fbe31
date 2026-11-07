import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/firebase/firestore_city_update_repository.dart';
import '../../domain/updates/city_update.dart';
import '../../infra/city_pack/city_pack_installer.dart';
import '../../infra/city_pack/city_pack_updater.dart';
import '../../infra/city_pack/sqlite_city_pack_repository.dart';
import '../providers/app_providers.dart';
import '../providers/active_trip_provider.dart';
import '../sync/account_deletion_controller.dart';

enum UpdatePhase {
  idle,
  checking,
  downloading,
  applying,
  restoring,
  current,
  complete,
  failed,
}

class CityUpdateState {
  const CityUpdateState({
    this.phase = UpdatePhase.idle,
    this.problem,
    this.received = 0,
    this.total = 0,
    this.version,
  });
  final UpdatePhase phase;
  final UpdateProblem? problem;
  final int received, total;
  final int? version;
  bool get busy => [
    UpdatePhase.checking,
    UpdatePhase.downloading,
    UpdatePhase.applying,
    UpdatePhase.restoring,
  ].contains(phase);
  bool get cancellable =>
      [UpdatePhase.checking, UpdatePhase.downloading].contains(phase);
}

final cityUpdateRepositoryProvider = Provider<CityUpdateRepository>(
  (ref) => ref.watch(useFirebaseProvider)
      ? FirestoreCityUpdateRepository()
      : DisabledCityUpdateRepository(),
);
final cityPackUpdaterProvider = Provider<CityPackUpdater>(
  (ref) => CityPackUpdater(installer: ref.watch(cityPackInstallerProvider)),
);
final cityUpdateAllowedProvider = Provider<bool>((ref) {
  final trip = ref.watch(activeTripProvider);
  final deleting = ref.watch(accountDeletionControllerProvider);
  return !(trip?.running ?? false) && !deleting;
});
final reloadCityPackProvider = Provider<Future<int> Function()>(
  (ref) => () async {
    final old = ref.read(appServicesProvider).asData?.value;
    final restoreGuest =
        old != null &&
        !old.useFirebase &&
        (old.auth.currentUser?.isAnonymous ?? false);
    ref.invalidate(appServicesProvider);
    final services = await ref.read(appServicesProvider.future);
    if (restoreGuest) await services.auth.signInAnonymously();
    return (await services.cityPack.packageInfo()).version;
  },
);
final cityUpdateProvider =
    NotifierProvider<CityUpdateController, CityUpdateState>(
      CityUpdateController.new,
    );

class CityUpdateController extends Notifier<CityUpdateState> {
  CityPackUpdater? _updater;
  bool _cancelled = false;
  @override
  CityUpdateState build() {
    ref.onDispose(() => _updater?.cancel());
    return const CityUpdateState();
  }

  void clear() {
    if (!state.busy) state = const CityUpdateState();
  }

  void cancel() {
    if (state.cancellable) {
      _cancelled = true;
      _updater?.cancel();
    }
  }

  Future<void> checkAndApply() async {
    if (state.busy) return;
    if (!ref.read(cityUpdateAllowedProvider)) {
      state = const CityUpdateState(
        phase: UpdatePhase.failed,
        problem: UpdateProblem.activeTrip,
      );
      return;
    }
    final services = ref.read(appServicesProvider).requireValue,
        pack = services.cityPack;
    if (pack is! SqliteCityPackRepository) {
      state = const CityUpdateState(
        phase: UpdatePhase.failed,
        problem: UpdateProblem.unavailable,
      );
      return;
    }
    final previous = pack.installed,
        installer = ref.read(cityPackInstallerProvider),
        updater = ref.read(cityPackUpdaterProvider);
    _updater = updater;
    _cancelled = false;
    state = const CityUpdateState(phase: UpdatePhase.checking);
    StagedCityUpdate? staged;
    var activated = false;
    void cancelled() {
      if (_cancelled || !ref.mounted) {
        throw const CityUpdateException(UpdateProblem.cancelled);
      }
    }

    try {
      final metadata = await ref.read(cityUpdateRepositoryProvider).check();
      cancelled();
      if (metadata == null) {
        throw const CityUpdateException(UpdateProblem.unavailable);
      }
      if (!updater.shouldDownload(
        metadata,
        previous,
        await installer.appVersion(),
      )) {
        state = CityUpdateState(
          phase: UpdatePhase.current,
          version: previous.manifest.version,
        );
        return;
      }
      cancelled();
      state = CityUpdateState(
        phase: UpdatePhase.downloading,
        version: metadata.version,
      );
      staged = await updater.download(
        metadata,
        progress: (received, total) {
          if (ref.mounted) {
            state = CityUpdateState(
              phase: UpdatePhase.downloading,
              received: received,
              total: total,
              version: metadata.version,
            );
          }
        },
      );
      cancelled();
      if (!ref.read(cityUpdateAllowedProvider)) {
        throw const CityUpdateException(UpdateProblem.activeTrip);
      }
      state = CityUpdateState(
        phase: UpdatePhase.applying,
        version: metadata.version,
      );
      await installer.activateUpdate(
        stage: staged.directory,
        source: staged.source,
        manifest: staged.manifest,
        minimum: staged.minimum,
        previous: previous,
      );
      activated = true;
      cancelled();
      final loaded = await ref.read(reloadCityPackProvider)();
      if (loaded != metadata.version) {
        throw const CityUpdateException(UpdateProblem.activation);
      }
      if (ref.mounted) {
        state = CityUpdateState(phase: UpdatePhase.complete, version: loaded);
      }
    } on Object catch (error) {
      if (activated) {
        if (ref.mounted) {
          state = const CityUpdateState(phase: UpdatePhase.restoring);
        }
        try {
          await installer.rollbackUpdate(previous);
          if (ref.mounted) await ref.read(reloadCityPackProvider)();
        } on Object {
          if (ref.mounted) {
            state = const CityUpdateState(
              phase: UpdatePhase.failed,
              problem: UpdateProblem.activation,
            );
          }
          return;
        }
      }
      if (ref.mounted) {
        state = CityUpdateState(
          phase: UpdatePhase.failed,
          problem: error is CityUpdateException
              ? error.problem
              : UpdateProblem.download,
        );
      }
    } finally {
      await staged?.discard();
      _updater = null;
    }
  }
}
