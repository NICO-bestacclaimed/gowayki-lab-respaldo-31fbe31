import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/app/settings/app_settings.dart';
import 'package:gowayki_lab/infra/notifications/trip_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'requestNotificationsPermission') return true;
          return true;
        });
  });
  tearDown(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'notification channels separate sound and vibration, and off creates no alert',
    () async {
      final notifications = LocalTripNotifications();
      expect(await notifications.requestPermission(), isTrue);
      for (final mode in AlarmMode.values) {
        await notifications.alert(title: 'T', body: 'B', mode: mode);
      }
      final shown = calls.where((c) => c.method == 'show').toList();
      expect(shown.length, 2);
      final sound = (shown[0].arguments as Map)['platformSpecifics'] as Map;
      final vibration = (shown[1].arguments as Map)['platformSpecifics'] as Map;
      expect(sound['channelId'], 'trip_alert_sound_v1');
      expect(sound['playSound'], isTrue);
      expect(sound['enableVibration'], isTrue);
      expect(vibration['channelId'], 'trip_alert_vibration_v1');
      expect(vibration['playSound'], isFalse);
      expect(vibration['enableVibration'], isTrue);
      expect(sound['importance'], 4);
      expect(sound['priority'], 1);
      await notifications.clear();
      expect(calls.last.method, 'cancel');
    },
  );
}
