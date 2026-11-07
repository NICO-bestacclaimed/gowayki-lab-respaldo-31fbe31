import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEvent { appReady, cityUpdateApplied, cityUpdateRejected, gameCompleted }

enum AppFault { flutterFramework, uncaughtAsync, cityUpdate, gameBridge }

/// Callers can provide only enums: no user text, locations, identifiers or payload maps.
abstract interface class AppTelemetry {
  bool get enabled;
  Future<void> event(AppEvent event);
  Future<void> failure(AppFault fault, StackTrace stack, {bool fatal = false});
}

class SilentTelemetry implements AppTelemetry {
  const SilentTelemetry();
  @override
  bool get enabled => false;
  @override
  Future<void> event(AppEvent event) async {}
  @override
  Future<void> failure(
    AppFault fault,
    StackTrace stack, {
    bool fatal = false,
  }) async {}
}

final appTelemetryProvider = Provider<AppTelemetry>(
  (ref) => const SilentTelemetry(),
);

abstract interface class TelemetryBackend {
  Future<void> configure(bool enabled);
  Future<void> event(String name);
  Future<void> failure(String code, StackTrace stack, {required bool fatal});
}

const eventNames = {
  AppEvent.appReady: 'gowayki_app_ready',
  AppEvent.cityUpdateApplied: 'city_update_applied',
  AppEvent.cityUpdateRejected: 'city_update_rejected',
  AppEvent.gameCompleted: 'game_completed',
};
StackTrace sanitizedStack(StackTrace stack) {
  final frames =
      RegExp(r'package:gowayki_lab/[A-Za-z0-9_./]+\.dart:[0-9]+:[0-9]+')
          .allMatches(stack.toString())
          .take(20)
          .map((match) => match.group(0)!)
          .toList();
  return StackTrace.fromString(
    frames.isEmpty
        ? '#0 redacted (package:gowayki_lab/observability.dart:0:0)'
        : frames.indexed
              .map((frame) => '#${frame.$1} app (${frame.$2})')
              .join('\n'),
  );
}

class SafeTelemetry implements AppTelemetry {
  SafeTelemetry(this.backend);
  final TelemetryBackend backend;
  @override
  bool get enabled => true;
  @override
  Future<void> event(AppEvent event) async {
    try {
      await backend.event(eventNames[event]!);
    } on Object {
      /* Diagnostics must not break an action. */
    }
  }

  @override
  Future<void> failure(
    AppFault fault,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    try {
      await backend.failure(
        'gowayki_${fault.name}',
        sanitizedStack(stack),
        fatal: fatal,
      );
    } on Object {
      /* Do not retry/log diagnostic failures with user context. */
    }
  }
}

Future<AppTelemetry> prepareTelemetry({
  required bool useFirebase,
  required bool supported,
  required bool release,
  required bool requested,
  required TelemetryBackend Function() backend,
}) async {
  if (!useFirebase || !supported) return const SilentTelemetry();
  TelemetryBackend? target;
  try {
    target = backend();
    final enabled = release && requested;
    await target.configure(enabled);
    return enabled ? SafeTelemetry(target) : const SilentTelemetry();
  } on Object {
    try {
      await target?.configure(false);
    } on Object {
      /* Native defaults stay disabled. */
    }
    return const SilentTelemetry();
  }
}
