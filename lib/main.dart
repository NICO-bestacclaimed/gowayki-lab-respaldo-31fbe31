import 'dart:async';
import 'package:flutter/foundation.dart';
import 'infra/observability/app_telemetry.dart';
import 'infra/observability/firebase_telemetry.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/providers/app_providers.dart';
import 'firebase_options.dart';

const bool kUseFirebase = bool.fromEnvironment(
  'USE_FIREBASE',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kUseFirebase) {
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await app.setAutomaticDataCollectionEnabled(false);
  }

  final telemetry = await prepareTelemetry(
    useFirebase: kUseFirebase,
    supported:
        !kIsWeb &&
        {
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform),
    release: kReleaseMode,
    requested: const bool.fromEnvironment(
      'ENABLE_OBSERVABILITY',
      defaultValue: false,
    ),
    backend: FirebaseTelemetryBackend.new,
  );
  if (telemetry.enabled) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        telemetry.failure(
          AppFault.flutterFramework,
          details.stack ?? StackTrace.current,
          fatal: true,
        ),
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(telemetry.failure(AppFault.uncaughtAsync, stack, fatal: true));
      return true;
    };
  }
  unawaited(telemetry.event(AppEvent.appReady));
  runApp(
    ProviderScope(
      overrides: [
        useFirebaseProvider.overrideWithValue(kUseFirebase),
        appTelemetryProvider.overrideWithValue(telemetry),
      ],
      child: const GowaykiLabApp(),
    ),
  );
}
