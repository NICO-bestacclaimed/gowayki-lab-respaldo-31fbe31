import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowayki_lab/domain/sync/personal_record.dart';
import 'package:gowayki_lab/domain/repositories/personal_sync_repository.dart';
import 'package:gowayki_lab/app/sync/personal_data.dart';
import 'package:gowayki_lab/app/sync/personal_sync.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/app/providers/search_providers.dart';
import 'package:gowayki_lab/app/library/local_library.dart';
import 'package:gowayki_lab/core/models/place_result.dart';

class Identity extends Notifier<PersonalScope> {
  @override
  PersonalScope build() => const PersonalScope(null);
  void set(PersonalScope next) => state = next;
}

final identity = NotifierProvider<Identity, PersonalScope>(Identity.new);

class Remote implements PersonalSyncRepository {
  bool server = true;
  int pushes = 0;
  Completer<void>? pause;
  final data = <String, Map<String, PersonalRecord>>{};
  final events = <String, StreamController<PersonalRemoteSnapshot>>{};
  @override
  Stream<PersonalRemoteSnapshot> watch(String uid) async* {
    final stream = events.putIfAbsent(uid, () => StreamController.broadcast());
    yield PersonalRemoteSnapshot(
      (data[uid] ?? {}).values.toList(),
      fromServer: server,
    );
    yield* stream.stream;
  }

  void emit(String uid) => events[uid]!.add(
    PersonalRemoteSnapshot(
      (data[uid] ?? {}).values.toList(),
      fromServer: server,
    ),
  );
  @override
  Future<List<PersonalRecord>> push(
    String uid,
    List<PersonalRecord> records,
  ) async {
    pushes++;
    await pause?.future;
    data[uid] = PersonalRecord.merge((data[uid] ?? {}).values, records);
    if (events[uid] != null) emit(uid);
    return records.map((r) => data[uid]![r.key]!).toList();
  }

  Future<void> close() async {
    for (final event in events.values) {
      await event.close();
    }
  }
}

PersonalRecord record(
  String key,
  int stamp,
  Object? value, {
  String device = 'remote',
}) => PersonalRecord(key: key, stamp: stamp, device: device, value: value);
const point = PlaceResult(
  id: 'stop:one',
  name: 'Paradero de prueba',
  address: '',
  latitude: -16.4,
  longitude: -71.5,
);
Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 150; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for synchronization');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer scope;
  late Remote remote;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = Remote();
    scope = ProviderContainer(
      overrides: [
        personalScopeProvider.overrideWith((ref) => ref.watch(identity)),
        useFirebaseProvider.overrideWithValue(true),
        personalSyncRepositoryProvider.overrideWithValue(remote),
      ],
    );
  });
  tearDown(() async {
    scope.dispose();
    await remote.close();
  });
  test(
    'new recent precedes migrated entries and records are immutable',
    () async {
      scope.dispose();
      SharedPreferences.setMockInitialValues({
        'navigation.recent_places':
            '[{"id":"old","name":"Old","address":"","lat":-16.4,"lon":-71.5}]',
      });
      scope = ProviderContainer(
        overrides: [useFirebaseProvider.overrideWithValue(false)],
      );
      await scope.read(personalDataProvider.future);
      await scope.read(recentPlacesProvider.notifier).remember(point);
      final data = scope.read(personalDataProvider).requireValue;
      expect(recentsFrom(data).first.id, point.id);
      expect(
        () => data.records[recentKey(point.id)]!.value['rank'] = 0,
        throwsUnsupportedError,
      );
      expect(recentKey(point.id), isNot(contains(point.id)));
    },
  );
  test(
    'merge is commutative, retains independent changes and deletion markers',
    () {
      final a = [record('line:a', 1, true), record('line:b', 3, null)];
      final b = [record('line:b', 2, true), record('line:c', 2, true)];
      final first = PersonalRecord.merge(a, b),
          second = PersonalRecord.merge(b, a);
      expect(first.keys.toSet(), second.keys.toSet());
      for (final key in first.keys) {
        expect(first[key]!.toJson(), second[key]!.toJson());
      }
      expect(first['line:b']!.value, isNull);
      expect(first['line:c']!.value, true);
      expect(PersonalRecord.merge(first.values, a)['line:b']!.value, isNull);
    },
  );
  test(
    'deterministic device tie and local clock advances beyond remote clock',
    () async {
      final a = record('line:x', 5, true, device: 'A'),
          b = record('line:x', 5, null, device: 'B');
      expect(PersonalRecord.merge([a], [b])['line:x']!.value, isNull);
      await scope.read(personalDataProvider.future);
      final future = DateTime.now().microsecondsSinceEpoch + 100000000;
      await scope.read(personalDataProvider.notifier).mergeRemote([
        record('line:x', future, true),
      ]);
      await scope
          .read(personalDataProvider.notifier)
          .edit((current) => {'line:x': null});
      expect(
        scope.read(personalDataProvider).requireValue.records['line:x']!.stamp,
        greaterThan(future),
      );
    },
  );
  test(
    'guest upgrade, sign-out and another account never expose private account data',
    () async {
      await scope.read(personalDataProvider.future);
      await scope
          .read(personalDataProvider.notifier)
          .edit((current) => {'line:guest': true});
      scope
          .read(identity.notifier)
          .set(const PersonalScope('alice', anonymous: false));
      expect(linesFrom(await scope.read(personalDataProvider.future)), {
        'guest',
      });
      await scope
          .read(personalDataProvider.notifier)
          .edit((current) => {'line:alice-private': true});
      scope.read(identity.notifier).set(const PersonalScope(null));
      expect(linesFrom(await scope.read(personalDataProvider.future)), isEmpty);
      scope
          .read(identity.notifier)
          .set(const PersonalScope('bob', anonymous: false));
      expect(linesFrom(await scope.read(personalDataProvider.future)), isEmpty);
      scope
          .read(identity.notifier)
          .set(const PersonalScope('alice', anonymous: false));
      expect(linesFrom(await scope.read(personalDataProvider.future)), {
        'guest',
        'alice-private',
      });
    },
  );
  test(
    'anonymous UID linking and collision preserve local favorites and saved trips',
    () async {
      scope.read(identity.notifier).set(const PersonalScope('anon'));
      await scope.read(personalDataProvider.future);
      final library = scope.read(localLibraryProvider.notifier);
      await scope.read(localLibraryProvider.future);
      await library.setSpecial(LibraryKind.home, point);
      await scope
          .read(personalDataProvider.notifier)
          .edit((current) => {'line:guest': true});
      scope
          .read(identity.notifier)
          .set(const PersonalScope('real', anonymous: false));
      final value = await scope.read(personalDataProvider.future);
      expect(linesFrom(value), {'guest'});
      expect(libraryFrom(value).special(LibraryKind.home)!.point!.id, point.id);
      scope.read(identity.notifier).set(const PersonalScope('real'));
      expect(linesFrom(await scope.read(personalDataProvider.future)), {
        'guest',
      });
    },
  );
  test(
    'local-only migration preserves legacy order and corrupted source is not overwritten',
    () async {
      scope.dispose();
      SharedPreferences.setMockInitialValues({'library.v1': 'broken'});
      scope = ProviderContainer(
        overrides: [useFirebaseProvider.overrideWithValue(false)],
      );
      await expectLater(
        scope.read(personalDataProvider.future),
        throwsFormatException,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('library.v1'), 'broken');
      expect(prefs.getString(const PersonalScope(null).key), isNull);
    },
  );
  test(
    'concurrent writes survive restart; 31st recent retires old coordinates, reorder persists',
    () async {
      await scope.read(personalDataProvider.future);
      final controller = scope.read(personalDataProvider.notifier);
      await Future.wait([
        controller.edit((c) => {'line:a': true}),
        controller.edit((c) => {'line:b': true}),
      ]);
      final recents = scope.read(recentPlacesProvider.notifier);
      for (var i = 0; i < 31; i++) {
        await recents.remember(
          PlaceResult(
            id: '$i',
            name: 'P$i',
            address: '',
            latitude: -16.4,
            longitude: -71.5,
          ),
        );
      }
      final snapshot = scope.read(personalDataProvider).requireValue;
      expect(recentsFrom(snapshot), hasLength(30));
      expect(snapshot.records[recentKey('0')]!.value, isNull);
      await recents.reorder(
        recentsFrom(snapshot).map((p) => p.id).toList().reversed.toList(),
      );
      scope.dispose();
      scope = ProviderContainer(
        overrides: [
          personalScopeProvider.overrideWithValue(const PersonalScope(null)),
          useFirebaseProvider.overrideWithValue(false),
        ],
      );
      final reopened = await scope.read(personalDataProvider.future);
      expect(linesFrom(reopened), {'a', 'b'});
      expect(recentsFrom(reopened).first.id, '1');
      await scope.read(recentPlacesProvider.notifier).remember(point);
      expect(
        recentsFrom(scope.read(personalDataProvider).requireValue).first.id,
        point.id,
      );
    },
  );
  test(
    'no upload before fresh server snapshot; merges cache and converges without resurrecting deletion',
    () async {
      remote.server = false;
      scope
          .read(identity.notifier)
          .set(const PersonalScope('alice', anonymous: false));
      await scope.read(personalDataProvider.future);
      await scope
          .read(personalDataProvider.notifier)
          .edit((c) => {'line:local': true});
      final subscription = scope.listen(personalSyncProvider, (_, next) {});
      await until(() => remote.events.containsKey('alice'));
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(remote.pushes, 0);
      remote.data['alice'] = {'line:other': record('line:other', 9, true)};
      remote.server = true;
      remote.emit('alice');
      await until(() => scope.read(personalSyncProvider) == SyncStatus.synced);
      expect(linesFrom(scope.read(personalDataProvider).requireValue), {
        'local',
        'other',
      });
      await scope
          .read(personalDataProvider.notifier)
          .edit((c) => {'line:other': null});
      await until(
        () =>
            remote.data['alice']?['line:other']?.value == null &&
            remote.data['alice']?['line:other'] != null,
      );
      await scope.read(personalDataProvider.notifier).mergeRemote([
        record('line:other', 9, true),
      ]);
      expect(linesFrom(scope.read(personalDataProvider).requireValue), {
        'local',
      });
      subscription.close();
    },
  );
  test(
    'old-session upload completion cannot merge into a new account',
    () async {
      scope
          .read(identity.notifier)
          .set(const PersonalScope('alice', anonymous: false));
      await scope.read(personalDataProvider.future);
      await scope
          .read(personalDataProvider.notifier)
          .edit((c) => {'line:private': true});
      remote.pause = Completer<void>();
      scope.listen(personalSyncProvider, (_, next) {});
      await until(() => remote.pushes == 1);
      scope
          .read(identity.notifier)
          .set(const PersonalScope('bob', anonymous: false));
      expect(linesFrom(await scope.read(personalDataProvider.future)), isEmpty);
      remote.pause!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(linesFrom(scope.read(personalDataProvider).requireValue), isEmpty);
    },
  );
  test(
    'unavailable or malformed remote leaves durable local data and exposes retry',
    () async {
      scope
          .read(identity.notifier)
          .set(const PersonalScope('alice', anonymous: false));
      await scope.read(personalDataProvider.future);
      await scope
          .read(personalDataProvider.notifier)
          .edit((c) => {'line:local': true});
      remote.data['alice'] = {
        'library:bad': record('library:bad', 2, {'kind': 'trip'}),
      };
      scope.listen(personalSyncProvider, (_, next) {});
      await until(
        () => scope.read(personalSyncProvider) == SyncStatus.unavailable,
      );
      expect(linesFrom(scope.read(personalDataProvider).requireValue), {
        'local',
      });
      remote.data['alice'] = {};
      scope.read(personalSyncProvider.notifier).retry();
      await until(() => scope.read(personalSyncProvider) == SyncStatus.synced);
      expect(remote.data['alice']!['line:local']!.value, true);
    },
  );
}
