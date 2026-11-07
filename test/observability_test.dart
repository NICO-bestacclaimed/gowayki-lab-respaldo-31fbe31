import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/infra/observability/app_telemetry.dart';

class RecordingBackend implements TelemetryBackend {
  final modes = <bool>[];
  final events = <String>[];
  final failures = <(String, String, bool)>[];
  bool fail = false;
  @override
  Future<void> configure(bool enabled) async {
    modes.add(enabled);
    if (fail) throw StateError('backend failure');
  }

  @override
  Future<void> event(String name) async {
    if (fail) throw StateError('backend failure');
    events.add(name);
  }

  @override
  Future<void> failure(
    String code,
    StackTrace stack, {
    required bool fatal,
  }) async {
    if (fail) throw StateError('backend failure');
    failures.add((code, stack.toString(), fatal));
  }
}

void main() {
  test(
    'demo and unsupported platforms never construct a Firebase backend',
    () async {
      for (final firebase in [false, true]) {
        for (final supported in [false, true]) {
          if (firebase && supported) continue;
          final telemetry = await prepareTelemetry(
            useFirebase: firebase,
            supported: supported,
            release: true,
            requested: true,
            backend: () => throw StateError('Must not instantiate SDK'),
          );
          expect(telemetry.enabled, isFalse);
          await telemetry.event(AppEvent.appReady);
        }
      }
    },
  );
  test(
    'collection requires Firebase, mobile, release and the explicit flag',
    () async {
      for (final release in [false, true]) {
        for (final requested in [false, true]) {
          final backend = RecordingBackend();
          final telemetry = await prepareTelemetry(
            useFirebase: true,
            supported: true,
            release: release,
            requested: requested,
            backend: () => backend,
          );
          expect(backend.modes, [release && requested]);
          expect(telemetry.enabled, release && requested);
          await telemetry.event(AppEvent.appReady);
          expect(
            backend.events,
            release && requested ? ['gowayki_app_ready'] : isEmpty,
          );
        }
      }
    },
  );
  test(
    'events contain fixed names; errors strip text, file paths, URLs and other package frames',
    () async {
      final backend = RecordingBackend();
      final telemetry = SafeTelemetry(backend);
      for (final event in AppEvent.values) {
        await telemetry.event(event);
      }
      expect(backend.events, eventNames.values.toList());
      final stack = StackTrace.fromString(
        '''Exception: correo@prueba.invalid token=SECRET lat=-16.4
#0 method (package:gowayki_lab/app/example.dart:12:3)
#1 method (file:///C:/Users/Persona/secret.dart:20:5)
#2 method (https://example.invalid/private?token=SECRET:1:1)
#3 method (package:firebase_auth/secret.dart:1:1)''',
      );
      await telemetry.failure(AppFault.uncaughtAsync, stack, fatal: true);
      expect(backend.failures.single, (
        'gowayki_uncaughtAsync',
        '#0 app (package:gowayki_lab/app/example.dart:12:3)',
        true,
      ));
      final fallback = sanitizedStack(
        StackTrace.fromString('correo@prueba.invalid'),
      ).toString();
      expect(fallback, contains('redacted'));
      expect(fallback, isNot(contains('correo')));
    },
  );
  test('diagnostic SDK errors do not become application errors', () async {
    final backend = RecordingBackend()..fail = true;
    final telemetry = await prepareTelemetry(
      useFirebase: true,
      supported: true,
      release: true,
      requested: true,
      backend: () => backend,
    );
    expect(telemetry.enabled, isFalse);
    final safe = SafeTelemetry(backend);
    await safe.event(AppEvent.cityUpdateRejected);
    await safe.failure(AppFault.cityUpdate, StackTrace.current);
  });
}
