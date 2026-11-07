import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import '../../domain/models/navigation_search.dart';
import '../../domain/planner/itinerary.dart';
import '../../domain/repositories/location_permission_repository.dart';
import '../../domain/repositories/position_repository.dart';
import '../../domain/repositories/trip_tracking_repository.dart';
import '../../domain/tracking/trip_tracker.dart';
import '../../infra/location/geolocator_trip_tracking.dart';
import '../../infra/notifications/trip_notifications.dart';
import '../../l10n/generated/app_localizations.dart';
import '../settings/app_settings.dart';
import 'app_providers.dart';
import 'location_providers.dart';
import 'location_ownership_provider.dart';

final tripTrackingRepositoryProvider = Provider<TripTrackingRepository>(
  (ref) => GeolocatorTripTracking(),
);
final tripNotificationsProvider = Provider<TripNotifications>(
  (ref) => LocalTripNotifications(),
);
final tripCanStartProvider = Provider<bool Function()>(
  (ref) => () {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  },
);
final tripClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

enum ActiveTripStatus { starting, active, completed, stopped, error }

class ActiveTrip {
  const ActiveTrip({
    required this.trip,
    required this.points,
    required this.progress,
    required this.status,
    this.stale = true,
    this.notificationError = false,
  });
  final Itinerary trip;
  final JourneyEndpoints points;
  final TripProgress progress;
  final ActiveTripStatus status;
  final bool stale, notificationError;
  bool get running =>
      status == ActiveTripStatus.starting || status == ActiveTripStatus.active;
  ActiveTrip copy({
    TripProgress? progress,
    ActiveTripStatus? status,
    bool? stale,
    bool? notificationError,
  }) => ActiveTrip(
    trip: trip,
    points: points,
    progress: progress ?? this.progress,
    status: status ?? this.status,
    stale: stale ?? this.stale,
    notificationError: notificationError ?? this.notificationError,
  );
}

final activeTripProvider = NotifierProvider<ActiveTripController, ActiveTrip?>(
  ActiveTripController.new,
);

class ActiveTripController extends Notifier<ActiveTrip?> {
  StreamSubscription<PositionFix>? _subscription;
  Timer? _timer;
  TripTracker? _tracker;
  int _generation = 0;
  Future<void>? _stopping;
  Future<void>? _alerts;
  late TripNotifications _notifications;
  late AppLocalizations _l;
  @override
  ActiveTrip? build() {
    _notifications = ref.read(tripNotificationsProvider);
    ref.onDispose(() {
      ++_generation;
      _timer?.cancel();
      final subscription = _subscription;
      _subscription = null;
      unawaited(() async {
        try {
          await subscription?.cancel();
          await _alerts;
          await _notifications.clear();
        } on Object {
          /* Provider scope is shutting down. */
        }
      }());
    });
    return null;
  }

  Future<void> start(
    Itinerary trip,
    JourneyEndpoints points,
    AppLocalizations l,
  ) async {
    if (state?.running ?? false) throw StateError('Trip already active');
    await _stopping;
    if (!ref.mounted) return;
    if (state?.running ?? false) throw StateError('Trip already active');
    final backend = ref.read(tripTrackingRepositoryProvider);
    if (!backend.supported) throw UnsupportedError('Mobile tracking only');
    final generation = ++_generation;
    bool current() => ref.mounted && generation == _generation;
    _l = l;
    _tracker = TripTracker(trip);
    state = ActiveTrip(
      trip: trip,
      points: points,
      progress: _tracker!.initial,
      status: ActiveTripStatus.starting,
    );
    try {
      if (await ref.read(locationPermissionRepositoryProvider).check() !=
              LocationAccess.allowed ||
          !await ref.read(positionRepositoryProvider).serviceEnabled()) {
        throw StateError('Location unavailable');
      }
      if (!current()) return;
      ref.read(tripOwnsLocationProvider.notifier).set(true);
      await ref.read(explorerLocationProvider.notifier).suspend();
      if (!current()) return;
      if (!ref.read(tripCanStartProvider)()) {
        throw StateError('App is not visible');
      }
      _subscription = backend
          .watch(
            title: 'GoWayki · ${l.activeTrip}',
            body: l.tripNotificationBody,
          )
          .listen(
            (fix) {
              if (!current()) return;
              final progress = _tracker!.update(
                fix,
                now: ref.read(tripClockProvider)(),
              );
              _accept(progress, generation);
            },
            onError: (Object error, StackTrace stack) {
              if (current()) {
                unawaited(
                  stop(
                    status: ActiveTripStatus.error,
                  ).catchError((Object error) {}),
                );
              }
            },
            onDone: () {
              if (current() && (state?.running ?? false)) {
                unawaited(
                  stop(
                    status: ActiveTripStatus.error,
                  ).catchError((Object error) {}),
                );
              }
            },
          );
      state = state!.copy(status: ActiveTripStatus.active);
      _timer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!current() || !(state?.running ?? false)) return;
        final fix = state!.progress.fix;
        final stale =
            fix == null ||
            ref.read(tripClockProvider)().difference(fix.at) >
                const Duration(seconds: 45);
        if (state!.stale != stale) state = state!.copy(stale: stale);
      });
    } on Object {
      if (current()) await stop(status: ActiveTripStatus.error);
      rethrow;
    }
  }

  void confirmStep() {
    if (state?.status != ActiveTripStatus.active || _tracker == null) return;
    _accept(_tracker!.confirmStep(), _generation);
  }

  void _accept(TripProgress progress, int generation) {
    final fix = progress.fix;
    final stale =
        fix == null ||
        ref.read(tripClockProvider)().difference(fix.at) >
            const Duration(seconds: 45);
    state = state!.copy(progress: progress, stale: stale);
    for (final alert in progress.alerts) {
      final mode =
          ref.read(appSettingsProvider).asData?.value.alarm ?? AlarmMode.sound;
      if (mode == AlarmMode.off) continue;
      final title = alert.kind == TripAlertKind.alight
          ? _l.alightAlertTitle
          : _l.transferAlertTitle;
      final body = alert.kind == TripAlertKind.alight
          ? _l.alightAlertBody(alert.stopName)
          : _l.transferAlertBody(alert.stopName);
      final previous = _alerts;
      _alerts = () async {
        if (previous != null) await previous;
        if (!ref.mounted || generation != _generation) return;
        try {
          await _notifications.alert(title: title, body: body, mode: mode);
        } on Object {
          if (ref.mounted && generation == _generation) {
            state = state!.copy(notificationError: true);
          }
        }
      }();
    }
    if (progress.phase == TripPhase.completed) {
      unawaited(
        stop(status: ActiveTripStatus.completed).catchError((Object error) {}),
      );
    }
  }

  Future<void> stop({ActiveTripStatus status = ActiveTripStatus.stopped}) =>
      _stopping ??= _stop(status).whenComplete(() => _stopping = null);
  Future<void> _stop(ActiveTripStatus status) async {
    ++_generation;
    _timer?.cancel();
    _timer = null;
    final subscription = _subscription;
    try {
      await subscription?.cancel();
      _subscription = null;
      await _alerts;
      await _notifications.clear();
      if (ref.mounted) {
        if (state != null) state = state!.copy(status: status);
        ref.read(tripOwnsLocationProvider.notifier).set(false);
      }
    } on Object {
      if (ref.mounted && state != null) {
        state = state!.copy(status: ActiveTripStatus.error);
      }
      // Keep location ownership until a successful explicit cleanup.
      rethrow;
    }
  }
}
