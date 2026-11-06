import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/planner/service_schedule.dart';

enum AlarmMode { sound, vibration, off }

class AppSettings {
  const AppSettings({
    this.languageCode = 'es',
    this.theme = ThemeMode.system,
    this.maxAccessMeters,
    this.avoidTransfers = false,
    this.alarm = AlarmMode.sound,
  });
  final String? languageCode;
  final ThemeMode theme;
  final int? maxAccessMeters;
  final bool avoidTransfers;
  final AlarmMode alarm;
  String get cityCode => 'arequipa';
  Locale? get locale => languageCode == null
      ? null
      : Locale(languageCode!, languageCode == 'es' ? 'PE' : null);
  int get maxBoardings => avoidTransfers ? 1 : 3;
  PlannerSettings plannerSettings(PlannerSettings base) => PlannerSettings(
    speeds: base.speeds,
    frequencies: base.frequencies,
    walkMetersPerMinute: base.walkMetersPerMinute,
    walkDistanceFactor: base.walkDistanceFactor,
    accessMeters: maxAccessMeters?.toDouble() ?? base.accessMeters,
    fallbackMeters: maxAccessMeters?.toDouble() ?? base.fallbackMeters,
  );
  AppSettings copyWith({
    String? languageCode,
    bool systemLanguage = false,
    ThemeMode? theme,
    int? maxAccessMeters,
    bool automaticWalking = false,
    bool? avoidTransfers,
    AlarmMode? alarm,
  }) => AppSettings(
    languageCode: systemLanguage ? null : languageCode ?? this.languageCode,
    theme: theme ?? this.theme,
    maxAccessMeters: automaticWalking
        ? null
        : maxAccessMeters ?? this.maxAccessMeters,
    avoidTransfers: avoidTransfers ?? this.avoidTransfers,
    alarm: alarm ?? this.alarm,
  );
  String encode() => jsonEncode({
    'city': cityCode,
    'language': languageCode,
    'theme': theme.name,
    'maxAccessMeters': maxAccessMeters,
    'avoidTransfers': avoidTransfers,
    'alarm': alarm.name,
  });
  factory AppSettings.decode(String? value) {
    if (value == null) return const AppSettings();
    try {
      final m = jsonDecode(value) as Map<String, dynamic>;
      return AppSettings(
        languageCode: m.containsKey('language') && m['language'] == null
            ? null
            : ['es', 'en'].contains(m['language'])
            ? m['language'] as String
            : 'es',
        theme:
            ThemeMode.values.where((v) => v.name == m['theme']).firstOrNull ??
            ThemeMode.system,
        maxAccessMeters: [400, 800, 1000, 1500].contains(m['maxAccessMeters'])
            ? m['maxAccessMeters'] as int
            : null,
        avoidTransfers: m['avoidTransfers'] == true,
        alarm:
            AlarmMode.values.where((v) => v.name == m['alarm']).firstOrNull ??
            AlarmMode.sound,
      );
    } on Object {
      return const AppSettings();
    }
  }
}

final localSettingsStorageProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);
final appSettingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<AppSettings> {
  static const storageKey = 'app.settings.v1';
  Future<void>? _pending;
  late SharedPreferences _prefs;
  @override
  Future<AppSettings> build() async {
    _prefs = await ref.watch(localSettingsStorageProvider.future);
    return AppSettings.decode(_prefs.getString(storageKey));
  }

  Future<void> save(AppSettings Function(AppSettings) change) async {
    final previous = _pending;
    final turn = Completer<void>();
    _pending = turn.future;
    if (previous != null) await previous;
    try {
      if (!ref.mounted) throw StateError('Settings disposed');
      final prefs = _prefs;
      if (!ref.mounted) throw StateError('Settings disposed');
      final next = change(state.requireValue);
      if (!await prefs.setString(storageKey, next.encode())) {
        throw StateError('Settings not saved');
      }
      if (ref.mounted) state = AsyncData(next);
    } finally {
      turn.complete();
    }
  }
}
