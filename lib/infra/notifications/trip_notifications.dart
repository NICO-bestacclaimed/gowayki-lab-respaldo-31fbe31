import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../app/settings/app_settings.dart';

abstract interface class TripNotifications {
  Future<bool> requestPermission();
  Future<void> alert({
    required String title,
    required String body,
    required AlarmMode mode,
  });
  Future<void> clear();
}

class LocalTripNotifications implements TripNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;
  Future<void> _init() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_trip'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true, badge: false) ??
        false;
  }

  @override
  Future<void> alert({
    required String title,
    required String body,
    required AlarmMode mode,
  }) async {
    if (mode == AlarmMode.off) return;
    await _init();
    final sound = mode == AlarmMode.sound;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await HapticFeedback.vibrate();
    }
    // Android channel behavior is immutable: sound and vibration need separate IDs.
    await _plugin.show(
      id: 601,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'trip_alert_${mode.name}_v1',
          sound ? 'GoWayki · Sonido y vibración' : 'GoWayki · Vibración',
          importance: Importance.high,
          priority: Priority.high,
          playSound: sound,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
          icon: 'ic_trip',
          category: AndroidNotificationCategory.navigation,
          timeoutAfter: 60000,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: sound,
          presentBadge: false,
        ),
      ),
    );
  }

  @override
  Future<void> clear() async {
    if (_initializing != null) {
      await _init();
      await _plugin.cancel(id: 601);
    }
  }
}
