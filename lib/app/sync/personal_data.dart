import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/sync/personal_record.dart';
import '../../core/models/place_result.dart';
import '../library/library_models.dart';
import '../providers/app_providers.dart';
import '../settings/app_settings.dart';
import 'account_deletion_state.dart';

class PersonalScope {
  const PersonalScope(this.uid, {this.anonymous = true});
  final String? uid;
  final bool anonymous;
  String get key => uid == null
      ? 'personal.guest.v1'
      : 'personal.user.${Uri.encodeComponent(uid!)}.v1';
  @override
  bool operator ==(Object other) =>
      other is PersonalScope &&
      other.uid == uid &&
      other.anonymous == anonymous;
  @override
  int get hashCode => Object.hash(uid, anonymous);
}

final personalScopeProvider = Provider<PersonalScope>((ref) {
  if (!ref.watch(useFirebaseProvider)) return const PersonalScope(null);
  final session = ref.watch(authStateProvider);
  final user = session.hasValue
      ? session.value
      : ref.read(authRepositoryProvider).currentUser;
  return PersonalScope(user?.id, anonymous: user?.isAnonymous ?? true);
});

String recentKey(String id) => 'recent:${sha256.convert(utf8.encode(id))}';

LocalLibrary libraryFrom(PersonalSnapshot snapshot) => LocalLibrary(
  items: snapshot.records.values
      .where((r) => r.key.startsWith('library:') && r.value != null)
      .map((r) => LibraryItem.fromJson(r.value))
      .toList(),
  order: (snapshot.value('order') as List?)?.cast<String>() ?? const [],
);
Set<String> linesFrom(PersonalSnapshot snapshot) => Set.unmodifiable(
  snapshot.records.values
      .where((r) => r.key.startsWith('line:') && r.value == true)
      .map((r) => r.key.substring(5)),
);
List<PersonalRecord> recentRecords(PersonalSnapshot snapshot) =>
    snapshot.records.values
        .where((r) => r.key.startsWith('recent:') && r.value != null)
        .toList()
      ..sort((a, b) {
        final rank = (b.value['rank'] as num).compareTo(a.value['rank'] as num);
        return rank == 0 ? a.key.compareTo(b.key) : rank;
      });
List<PlaceResult> recentsFrom(PersonalSnapshot snapshot) => List.unmodifiable(
  recentRecords(snapshot).take(30).map((r) => decodePoint(r.value['point'])),
);

void validatePersonalRecord(PersonalRecord r) {
  if (r.value == null) {
    if (r.key == 'order') throw const FormatException('Missing order');
  } else if (r.key.startsWith('library:')) {
    final item = LibraryItem.fromJson(r.value);
    if (r.key != 'library:${item.id}') {
      throw const FormatException('Bookmark identity');
    }
  } else if (r.key.startsWith('line:')) {
    if (r.value != true) throw const FormatException('Line favorite');
  } else if (r.key.startsWith('recent:')) {
    final point = decodePoint(r.value['point']);
    if (r.key != recentKey(point.id) || r.value['rank'] is! int) {
      throw const FormatException('Recent identity');
    }
  } else if (r.key == 'order') {
    if (r.value is! List ||
        (r.value as List).length > 10000 ||
        (r.value as List).any((v) => v is! String)) {
      throw const FormatException('Bookmark order');
    }
  } else {
    throw const FormatException('Unknown personal key');
  }
  if (r.key != 'order' &&
      !['library:', 'line:', 'recent:'].any(r.key.startsWith)) {
    throw const FormatException('Unknown personal key');
  }
}

final personalDataProvider =
    AsyncNotifierProvider<PersonalDataController, PersonalSnapshot>(
      PersonalDataController.new,
      retry: (count, error) => null,
    );

class PersonalDataController extends AsyncNotifier<PersonalSnapshot> {
  Future<void>? _pending;
  PersonalScope? _scope, _previous;
  late SharedPreferences _prefs;
  String _device = '';
  @override
  Future<PersonalSnapshot> build() async {
    final scope = ref.watch(personalScopeProvider);
    final previous = _previous;
    _previous = scope;
    _scope = scope;
    final pendingWrite = _pending;
    if (pendingWrite != null) await pendingWrite;
    final existing = ref.exists(appServicesProvider)
        ? ref.read(appServicesProvider).asData?.value.localPreferences
        : null;
    final SharedPreferences prefs;
    if (existing != null) {
      prefs = existing;
    } else {
      prefs = await ref.watch(localSettingsStorageProvider.future);
    }
    _prefs = prefs;
    if (scope.uid != null && prefs.getBool(deletionFlag(scope.uid!)) == true) {
      return PersonalSnapshot([]);
    }
    if (!ref.mounted || _scope != scope) throw StateError('Session changed');
    var device = prefs.getString('personal.device');
    if (device == null) {
      final random = Random.secure();
      device = List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      if (!await prefs.setString('personal.device', device)) {
        throw StateError('Not saved');
      }
    }
    _device = device;
    final raw = prefs.getString(scope.key);
    var snapshot = raw == null
        ? (scope.uid == null ? _legacy(prefs) : PersonalSnapshot([]))
        : PersonalSnapshot.decode(raw);
    // Never import a real account into another account or into guest storage.
    if (scope.uid != null && (raw == null || previous?.uid == null)) {
      final guest = prefs.getString(const PersonalScope(null).key);
      final unowned = guest == null
          ? _legacy(prefs)
          : PersonalSnapshot.decode(guest);
      snapshot = PersonalSnapshot(
        PersonalRecord.merge(
          snapshot.records.values,
          unowned.records.values,
        ).values,
      );
    }
    if (scope.uid != null &&
        previous?.uid != null &&
        previous!.anonymous &&
        previous.uid != scope.uid) {
      final anonymous = prefs.getString(previous.key);
      if (anonymous != null) {
        snapshot = PersonalSnapshot(
          PersonalRecord.merge(
            snapshot.records.values,
            PersonalSnapshot.decode(anonymous).records.values,
          ).values,
        );
      }
    }
    for (final record in snapshot.records.values) {
      validatePersonalRecord(record);
    }
    if (!await prefs.setString(scope.key, snapshot.encode())) {
      throw StateError('Not saved');
    }
    if (scope.uid != null && (raw == null || previous?.uid == null)) {
      // The target is durable before retiring the unowned guest copy.
      await prefs.setString(
        const PersonalScope(null).key,
        PersonalSnapshot([]).encode(),
      );
      await prefs.setString('library.v1', LocalLibrary().encode());
      await prefs.setStringList('favorites.line_ids', []);
      await prefs.setString('navigation.recent_places', '[]');
    }
    return snapshot;
  }

  PersonalSnapshot _legacy(SharedPreferences prefs) {
    final records = <PersonalRecord>[];
    void add(String key, Object? value) => records.add(
      PersonalRecord(key: key, stamp: 0, device: 'legacy', value: value),
    );
    // A malformed existing library is reported, never silently overwritten.
    final library = LocalLibrary.decode(prefs.getString('library.v1'));
    for (final item in library.items) {
      add('library:${item.id}', item.toJson());
    }
    if (library.order.isNotEmpty) add('order', library.order);
    for (final id in prefs.getStringList('favorites.line_ids') ?? <String>[]) {
      add('line:$id', true);
    }
    final recent =
        jsonDecode(prefs.getString('navigation.recent_places') ?? '[]') as List;
    for (final (i, point) in recent.take(30).indexed) {
      final decoded = decodePoint(point);
      add(recentKey(decoded.id), {
        'point': encodePoint(decoded),
        'rank': 30 - i,
      });
    }
    return PersonalSnapshot(records);
  }

  Future<void> _change(
    PersonalSnapshot Function(PersonalSnapshot current) change,
  ) async {
    final scope = ref.read(personalScopeProvider);
    if (state.isLoading || !state.hasValue) await future;
    final previous = _pending, turn = Completer<void>();
    _pending = turn.future;
    if (previous != null) await previous;
    try {
      if (!ref.mounted || _scope != scope) throw StateError('Session changed');
      if (scope.uid != null &&
          _prefs.getBool(deletionFlag(scope.uid!)) == true) {
        throw StateError('Account deletion pending');
      }
      final next = change(state.requireValue);
      if (next.encode() == state.requireValue.encode()) return;
      if (!await _prefs.setString(scope.key, next.encode())) {
        throw StateError('Not saved');
      }
      if (scope.uid == null) {
        // Compatibility with local-only installations; account data never uses these keys.
        await _prefs.setString('library.v1', libraryFrom(next).encode());
        await _prefs.setStringList(
          'favorites.line_ids',
          linesFrom(next).toList()..sort(),
        );
        await _prefs.setString(
          'navigation.recent_places',
          jsonEncode(recentsFrom(next).map(encodePoint).toList()),
        );
      }
      if (ref.mounted && _scope == scope) state = AsyncData(next);
    } finally {
      turn.complete();
      if (identical(_pending, turn.future)) _pending = null;
    }
  }

  Future<void> settle() async {
    if (state.isLoading) {
      try {
        await future;
      } on Object {
        /* Explicit deletion can also clear a damaged cache. */
      }
    }
    final pending = _pending;
    if (pending != null) await pending;
  }

  PersonalSnapshot _edit(
    PersonalSnapshot current,
    Map<String, Object?> values,
  ) {
    var clock = max(
      DateTime.now().toUtc().microsecondsSinceEpoch,
      current.clock + 1,
    );
    return PersonalSnapshot(
      PersonalRecord.merge(
        current.records.values,
        values.entries.map(
          (e) => PersonalRecord(
            key: e.key,
            stamp: clock++,
            device: _device,
            value: e.value,
          ),
        ),
      ).values,
    );
  }

  Future<void> edit(
    Map<String, Object?> Function(PersonalSnapshot current) change,
  ) => _change((current) {
    var next = _edit(current, change(current));
    final overflow = recentRecords(next).skip(30).toList();
    if (overflow.isNotEmpty) {
      next = _edit(next, {for (final r in overflow) r.key: null});
    }
    for (final record in next.records.values) {
      validatePersonalRecord(record);
    }
    return next;
  });
  Future<void> mergeRemote(Iterable<PersonalRecord> records) =>
      _change((current) {
        for (final record in records) {
          validatePersonalRecord(record);
        }
        var next = PersonalSnapshot(
          PersonalRecord.merge(current.records.values, records).values,
        );
        final overflow = recentRecords(next).skip(30).toList();
        if (overflow.isNotEmpty) {
          next = _edit(next, {for (final r in overflow) r.key: null});
        }
        return next;
      });
  Future<void> changeLibrary(LocalLibrary Function(LocalLibrary) change) =>
      edit((current) {
        final before = libraryFrom(current),
            after = change(libraryFrom(current));
        final values = <String, Object?>{};
        final next = {for (final item in after.items) item.id: item};
        for (final item in before.items) {
          if (!next.containsKey(item.id)) values['library:${item.id}'] = null;
        }
        for (final item in after.items) {
          final old = before.items.where((v) => v.id == item.id).firstOrNull;
          if (jsonEncode(old?.toJson()) != jsonEncode(item.toJson())) {
            values['library:${item.id}'] = item.toJson();
          }
        }
        if (jsonEncode(before.order) != jsonEncode(after.order)) {
          values['order'] = after.order;
        }
        return values;
      });
}
