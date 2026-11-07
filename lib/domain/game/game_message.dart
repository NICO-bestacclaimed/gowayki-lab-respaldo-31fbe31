import 'dart:convert';

sealed class GameMessage {
  const GameMessage();
  static GameMessage? parse(String raw) {
    if (raw.length > 512) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      switch (data['type']) {
        case 'score':
          final value = data['value'], duration = data['durationMs'];
          if (value is! int ||
              duration is! int ||
              value < 0 ||
              value > 5000 ||
              duration < 1000 ||
              duration > 120000 ||
              value > duration / 1000 * 30 + 30) {
            return null;
          }
          return GameScore(value, duration);
        case 'sound':
          return data['value'] is bool
              ? GameSound(data['value'] as bool)
              : null;
        case 'haptic':
          return const GameHaptic();
      }
    } on Object {
      /* Invalid messages never update local records. */
    }
    return null;
  }
}

class GameScore extends GameMessage {
  GameScore(this.value, this.durationMs);
  final int value, durationMs;
}

class GameSound extends GameMessage {
  GameSound(this.enabled);
  final bool enabled;
}

class GameHaptic extends GameMessage {
  const GameHaptic();
}

bool isLocalGameNavigation(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'file' &&
      uri.host.isEmpty &&
      uri.path.endsWith('/flutter_assets/assets/game/index.html') &&
      !uri.pathSegments.contains('..') &&
      !uri.hasQuery &&
      !uri.hasFragment;
}
