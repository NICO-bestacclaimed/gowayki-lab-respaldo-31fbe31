import 'dart:async';
import '../../../infra/observability/app_telemetry.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../domain/game/game_message.dart';
import '../../../shared/l10n/l10n.dart';
import '../../game/game_preferences.dart';
import '../../game/weekly_scores.dart';
import '../../providers/app_providers.dart';
import '../../settings/app_settings.dart';

final gameSupportedProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform),
);

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});
  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  WebViewController? _web;
  Object? _error;
  bool _loaded = false;
  int _generation = 0;
  late final GameBridge _bridge;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bridge = GameBridge(
      saveScore: (value) =>
          ref.read(gamePreferencesProvider.notifier).score(value),
      saveSound: (value) =>
          ref.read(gamePreferencesProvider.notifier).sound(value),
      haptic: HapticFeedback.vibrate,
    );
    if (ref.read(gameSupportedProvider)) _boot();
  }

  Future<void> _boot() async {
    final generation = ++_generation;
    bool current() => mounted && generation == _generation;
    try {
      await ref.read(gamePreferencesProvider.future);
      if (!current()) return;
      final web = WebViewController();
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.setBackgroundColor(const Color(0xfff5efe4));
      await web.addJavaScriptChannel(
        'GoWayki',
        onMessageReceived: (message) async {
          if (!current()) return;
          try {
            final result = GameMessage.parse(message.message);
            await _bridge.handle(
              message.message,
              alarm:
                  ref.read(appSettingsProvider).asData?.value.alarm ??
                  AlarmMode.sound,
            );
            if (result is GameScore) {
              await ref.read(weeklyScoresProvider.notifier).record(result);
              if (current()) {
                unawaited(
                  ref.read(appTelemetryProvider).event(AppEvent.gameCompleted),
                );
              }
            }
          } on Object {
            if (mounted && generation == _generation) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.gameSaveFailed)),
              );
            }
          }
        },
      );
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => isLocalGameNavigation(request.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) async {
            if (!current()) return;
            try {
              await _configure(web);
              if (current()) setState(() => _loaded = true);
            } on Object {
              if (current()) {
                setState(
                  () => _error = StateError('Game configuration failed'),
                );
              }
            }
          },
          onWebResourceError: (error) {
            if (current() && error.isForMainFrame != false) {
              setState(() => _error = error);
            }
          },
        ),
      );
      if (!current()) return;
      setState(() {
        _web = web;
        _error = null;
        _loaded = false;
      });
      await web.loadFlutterAsset('assets/game/index.html');
    } on Object catch (error) {
      if (current()) setState(() => _error = error);
    }
  }

  Future<void> _configure(WebViewController web) async {
    if (!mounted) return;
    final prefs = ref.read(gamePreferencesProvider).requireValue;
    final settings =
        ref.read(appSettingsProvider).asData?.value ?? const AppSettings();
    final user = ref.read(authStateProvider).asData?.value;
    final config = jsonEncode({
      'name': user?.displayName ?? context.l10n.guest,
      'best': prefs.best,
      'sound': prefs.sound,
      'vibration': settings.alarm != AlarmMode.off,
      'language': Localizations.localeOf(context).languageCode,
    });
    await web.runJavaScript('window.WaykiGame.configure($config);');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded && _web != null) {
      _configure(_web!).catchError((Object error) {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _pause() {
    final web = _web;
    if (web != null && _loaded) {
      web
          .runJavaScript('window.WaykiGame.pause();')
          .catchError((Object error) {});
    }
  }

  @override
  void dispose() {
    _pause();
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.listen(gamePreferencesProvider, (before, next) {
      if (_loaded && next.hasValue && _web != null) {
        _configure(_web!).catchError((Object error) {});
      }
    });
    ref.listen(appSettingsProvider, (before, next) {
      if (_loaded && next.hasValue && _web != null) {
        _configure(_web!).catchError((Object error) {});
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Wayki Combi')),
      body: !ref.watch(gameSupportedProvider)
          ? Center(child: Text(l.gameMobileOnly))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.gameLoadFailed),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(gamePreferencesProvider);
                        _boot();
                      },
                      child: Text(l.retry),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                if (_web != null) WebViewWidget(controller: _web!),
                if (!_loaded) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
