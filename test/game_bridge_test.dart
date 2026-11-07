import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowayki_lab/domain/game/game_message.dart';
import 'package:gowayki_lab/app/game/game_preferences.dart';
import 'package:gowayki_lab/app/settings/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'score channel validates types, duration, bounds, malformed and oversized messages',
    () {
      final valid =
          GameMessage.parse('{"type":"score","value":120,"durationMs":90000}')
              as GameScore;
      expect(valid.value, 120);
      expect(valid.durationMs, 90000);
      for (final raw in [
        '[]',
        'null',
        'bad',
        '{}',
        '{"type":"score","value":-1,"durationMs":90000}',
        '{"type":"score","value":99999,"durationMs":90000}',
        '{"type":"score","value":100,"durationMs":10}',
        '{"type":"score","value":120,"durationMs":120001}',
        '{"type":"score","value":12.5,"durationMs":90000}',
        '{"type":"score","value":"120","durationMs":90000}',
        '{"type":"score","value":5000,"durationMs":1000}',
        jsonEncode({'type': 'score', 'padding': 'x' * 600}),
      ]) {
        expect(GameMessage.parse(raw), isNull, reason: raw);
      }
    },
  );
  test('navigation accepts only the local bundled game index', () {
    expect(
      isLocalGameNavigation(
        'file:///android_asset/flutter_assets/assets/game/index.html',
      ),
      isTrue,
    );
    expect(
      isLocalGameNavigation(
        'file:///app/Frameworks/App.framework/flutter_assets/assets/game/index.html',
      ),
      isTrue,
    );
    for (final url in [
      'https://example.com/index.html',
      'javascript:alert(1)',
      'file:///etc/passwd',
      'file://remote/flutter_assets/assets/game/index.html',
      'file:///android_asset/flutter_assets/assets/game/index.html?remote=1',
    ]) {
      expect(isLocalGameNavigation(url), isFalse);
    }
  });
  test(
    'record and sound persist, lower scores cannot replace the record, concurrent writes retain both',
    () async {
      SharedPreferences.setMockInitialValues({});
      var scope = ProviderContainer();
      await scope.read(gamePreferencesProvider.future);
      final preferences = scope.read(gamePreferencesProvider.notifier);
      final scores = <int>[];
      final bridge = GameBridge(
        saveScore: (v) async {
          scores.add(v);
          await preferences.score(v);
        },
        saveSound: preferences.sound,
        haptic: () async {},
      );
      await Future.wait([
        bridge.handle(
          '{"type":"score","value":120,"durationMs":90000}',
          alarm: AlarmMode.sound,
        ),
        bridge.handle('{"type":"sound","value":true}', alarm: AlarmMode.sound),
      ]);
      await bridge.handle(
        '{"type":"score","value":10,"durationMs":3000}',
        alarm: AlarmMode.sound,
      );
      await bridge.handle(
        '{"type":"score","value":999999,"durationMs":90000}',
        alarm: AlarmMode.sound,
      );
      expect(scores, [120, 10]);
      scope.dispose();
      scope = ProviderContainer();
      final restored = await scope.read(gamePreferencesProvider.future);
      expect(restored.best, 120);
      expect(restored.sound, isTrue);
      scope.dispose();
    },
  );
  test(
    'haptic messages respect disabled mode and throttle repeated collisions',
    () async {
      var count = 0;
      var now = DateTime.utc(2026, 11, 7);
      final bridge = GameBridge(
        saveScore: (_) async {},
        saveSound: (_) async {},
        haptic: () async {
          count++;
        },
        clock: () => now,
      );
      await bridge.handle('{"type":"haptic"}', alarm: AlarmMode.off);
      expect(count, 0);
      await bridge.handle('{"type":"haptic"}', alarm: AlarmMode.vibration);
      await bridge.handle('{"type":"haptic"}', alarm: AlarmMode.sound);
      expect(count, 1);
      now = now.add(const Duration(seconds: 2));
      await bridge.handle('{"type":"haptic"}', alarm: AlarmMode.sound);
      expect(count, 2);
      await bridge.handle(
        '{"type":"sound","value":"true"}',
        alarm: AlarmMode.sound,
      );
      expect(count, 2);
    },
  );
}
