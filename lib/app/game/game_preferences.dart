import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings/app_settings.dart';
import '../../domain/game/game_message.dart';

class GamePreferences {
  const GamePreferences({this.best = 0, this.sound = false});
  final int best;
  final bool sound;
  static GamePreferences decode(String? value) {
    try {
      final data = jsonDecode(value ?? '{}') as Map<String, dynamic>;
      return GamePreferences(
        best: data['best'] is int && data['best'] >= 0 && data['best'] <= 5000
            ? data['best'] as int
            : 0,
        sound: data['sound'] == true,
      );
    } on Object {
      return const GamePreferences();
    }
  }

  String encode() => jsonEncode({'version': 1, 'best': best, 'sound': sound});
}

final gamePreferencesProvider =
    AsyncNotifierProvider<GamePreferencesController, GamePreferences>(
      GamePreferencesController.new,
      retry: (count, error) => null,
    );

class GamePreferencesController extends AsyncNotifier<GamePreferences> {
  static const storageKey = 'game.preferences.v1';
  late SharedPreferences _prefs;
  Future<void>? _pending;
  @override
  Future<GamePreferences> build() async {
    _prefs = await ref.watch(localSettingsStorageProvider.future);
    return GamePreferences.decode(_prefs.getString(storageKey));
  }

  Future<void> _save(GamePreferences Function(GamePreferences) change) async {
    final previous = _pending, turn = Completer<void>();
    _pending = turn.future;
    if (previous != null) await previous;
    try {
      if (!ref.mounted) return;
      final next = change(state.requireValue);
      if (!await _prefs.setString(storageKey, next.encode())) {
        throw StateError('Game record not saved');
      }
      if (ref.mounted) state = AsyncData(next);
    } finally {
      turn.complete();
    }
  }

  Future<void> score(int value) => _save((old) {
    if (value < 0 || value > 5000) throw ArgumentError('Invalid score');
    return GamePreferences(
      best: value > old.best ? value : old.best,
      sound: old.sound,
    );
  });
  Future<void> sound(bool enabled) =>
      _save((old) => GamePreferences(best: old.best, sound: enabled));
}

/// Shared by the native JavaScript channel and its tests. Unknown messages are ignored.
class GameBridge {
  GameBridge({
    required this.saveScore,
    required this.saveSound,
    required this.haptic,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final Future<void> Function(int) saveScore;
  final Future<void> Function(bool) saveSound;
  final Future<void> Function() haptic;
  final DateTime Function() clock;
  DateTime? _lastHaptic;
  Future<void> handle(String raw, {required AlarmMode alarm}) async {
    switch (GameMessage.parse(raw)) {
      case GameScore score:
        await saveScore(score.value);
      case GameSound sound:
        await saveSound(sound.enabled);
      case GameHaptic():
        final now = clock();
        if (alarm != AlarmMode.off &&
            (_lastHaptic == null ||
                now.difference(_lastHaptic!) >= const Duration(seconds: 1))) {
          _lastHaptic = now;
          await haptic();
        }
      case null:
        break;
    }
  }
}
