import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'app_telemetry.dart';

class FirebaseTelemetryBackend implements TelemetryBackend {
  final _analytics = FirebaseAnalytics.instance;
  final _crashes = FirebaseCrashlytics.instance;
  @override
  Future<void> configure(bool enabled) async {
    await _analytics.setAnalyticsCollectionEnabled(false);
    await _crashes.setCrashlyticsCollectionEnabled(false);
    await _analytics.setConsent(
      analyticsStorageConsentGranted: enabled,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
    await _analytics.setDefaultEventParameters(null);
    await _analytics.setUserId(id: null);
    await _crashes.setUserIdentifier('');
    if (!enabled) {
      await _crashes.deleteUnsentReports();
      return;
    }
    await _analytics.setAnalyticsCollectionEnabled(true);
    await _crashes.setCrashlyticsCollectionEnabled(true);
  }

  @override
  Future<void> event(String name) => _analytics.logEvent(name: name);
  @override
  Future<void> failure(String code, StackTrace stack, {required bool fatal}) =>
      _crashes.recordError(code, stack, fatal: fatal, printDetails: false);
}
