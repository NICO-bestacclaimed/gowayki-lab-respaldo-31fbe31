import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings/app_settings.dart';

String deletionFlag(String uid) =>
    'account.deleting.v1.${Uri.encodeComponent(uid)}';
String weeklyStorageKey(String uid) =>
    'game.weekly.v1.${Uri.encodeComponent(uid)}';
final accountDeletionJobsProvider =
    AsyncNotifierProvider<AccountDeletionJobs, Set<String>>(
      AccountDeletionJobs.new,
      retry: (count, error) => null,
    );

class AccountDeletionJobs extends AsyncNotifier<Set<String>> {
  late SharedPreferences _prefs;
  @override
  Future<Set<String>> build() async {
    _prefs = await ref.watch(localSettingsStorageProvider.future);
    const prefix = 'account.deleting.v1.';
    return Set.unmodifiable(
      _prefs
          .getKeys()
          .where((key) => key.startsWith(prefix) && _prefs.getBool(key) == true)
          .map((key) => Uri.decodeComponent(key.substring(prefix.length))),
    );
  }

  Future<void> start(String uid) async {
    if (state.isLoading || !state.hasValue) await future;
    if (!await _prefs.setBool(deletionFlag(uid), true)) {
      throw StateError('Deletion state not saved');
    }
    state = AsyncData(Set.unmodifiable({...state.requireValue, uid}));
  }

  Future<void> clearCaches(String uid) async {
    if (state.isLoading || !state.hasValue) await future;
    if (!await _prefs.remove('personal.user.${Uri.encodeComponent(uid)}.v1')) {
      throw StateError('Cache not erased');
    }
    if (!await _prefs.remove(weeklyStorageKey(uid))) {
      throw StateError('Scores not erased');
    }
  }

  Future<void> finish(String uid) async {
    if (state.isLoading || !state.hasValue) await future;
    if (!await _prefs.remove(deletionFlag(uid))) {
      throw StateError('Deletion state not cleared');
    }
    state = AsyncData(Set.unmodifiable({...state.requireValue}..remove(uid)));
  }
}
