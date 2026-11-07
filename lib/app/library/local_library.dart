import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/place_result.dart';
import '../../domain/models/navigation_search.dart';
import '../settings/app_settings.dart';

enum LibraryKind { home, work, place, stop, trip }

Map<String, Object?> encodePoint(PlaceResult point) => {
  'id': point.id,
  'name': point.name,
  'address': point.address,
  'lat': point.latitude,
  'lon': point.longitude,
};
PlaceResult decodePoint(dynamic value) {
  final m = value as Map<String, dynamic>;
  final lat = (m['lat'] as num).toDouble(), lon = (m['lon'] as num).toDouble();
  if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
    throw const FormatException('Invalid point');
  }
  return PlaceResult(
    id: m['id'] as String,
    name: m['name'] as String,
    address: m['address'] as String,
    latitude: lat,
    longitude: lon,
  );
}

class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.kind,
    required this.label,
    this.point,
    this.trip,
  });
  final String id, label;
  final LibraryKind kind;
  final PlaceResult? point;
  final JourneyEndpoints? trip;
  static String tripId(JourneyEndpoints points) =>
      'trip:${Uri.encodeComponent(points.origin.id)}:${Uri.encodeComponent(points.destination.id)}';
  factory LibraryItem.journey(JourneyEndpoints points) => LibraryItem(
    id: tripId(points),
    kind: LibraryKind.trip,
    label: '${points.origin.name} → ${points.destination.name}',
    trip: points,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'label': label,
    if (point != null) 'point': encodePoint(point!),
    if (trip != null)
      'trip': {
        'origin': encodePoint(trip!.origin),
        'destination': encodePoint(trip!.destination),
      },
  };
  factory LibraryItem.fromJson(dynamic value) {
    final m = value as Map<String, dynamic>;
    final kind = LibraryKind.values.byName(m['kind'] as String);
    final point = m['point'] == null ? null : decodePoint(m['point']);
    final trip = m['trip'] == null
        ? null
        : JourneyEndpoints(
            origin: decodePoint(m['trip']['origin']),
            destination: decodePoint(m['trip']['destination']),
          );
    if (kind == LibraryKind.trip ? trip == null : point == null) {
      throw const FormatException('Incomplete bookmark');
    }
    return LibraryItem(
      id: m['id'] as String,
      kind: kind,
      label: m['label'] as String,
      point: point,
      trip: trip,
    );
  }
}

class LocalLibrary {
  LocalLibrary({
    List<LibraryItem> items = const [],
    List<String> order = const [],
  }) : items = List.unmodifiable(items),
       order = List.unmodifiable(order);
  final List<LibraryItem> items;
  final List<String> order;
  List<LibraryItem> get orderedItems {
    final ranks = {for (final (i, id) in order.indexed) id: i};
    final initial = {for (final (i, item) in items.indexed) item.id: i};
    return [...items]..sort(
      (a, b) => (ranks[a.id] ?? order.length + initial[a.id]!).compareTo(
        ranks[b.id] ?? order.length + initial[b.id]!,
      ),
    );
  }

  bool contains(String id) => items.any((item) => item.id == id);
  LibraryItem? special(LibraryKind kind) =>
      items.where((item) => item.kind == kind).firstOrNull;
  String encode() => jsonEncode({
    'version': 1,
    'items': items.map((item) => item.toJson()).toList(),
    'order': order,
  });
  factory LocalLibrary.decode(String? text) {
    if (text == null) return LocalLibrary();
    final m = jsonDecode(text) as Map<String, dynamic>;
    if (m['version'] != 1) throw const FormatException('Unsupported library');
    final items = (m['items'] as List).map(LibraryItem.fromJson).toList();
    if (items.map((item) => item.id).toSet().length != items.length) {
      throw const FormatException('Duplicate bookmarks');
    }
    return LocalLibrary(
      items: items,
      order: (m['order'] as List).cast<String>(),
    );
  }
}

final localLibraryProvider =
    AsyncNotifierProvider<LibraryController, LocalLibrary>(
      LibraryController.new,
      retry: (count, error) => null,
    );

class LibraryController extends AsyncNotifier<LocalLibrary> {
  static const storageKey = 'library.v1';
  late SharedPreferences _prefs;
  Future<void>? _pending;
  @override
  Future<LocalLibrary> build() async {
    _prefs = await ref.watch(localSettingsStorageProvider.future);
    return LocalLibrary.decode(_prefs.getString(storageKey));
  }

  Future<void> _change(LocalLibrary Function(LocalLibrary) change) async {
    final previous = _pending, turn = Completer<void>();
    _pending = turn.future;
    if (previous != null) await previous;
    try {
      if (!ref.mounted) throw StateError('Library disposed');
      final next = change(state.requireValue);
      if (!await _prefs.setString(storageKey, next.encode())) {
        throw StateError('Not saved');
      }
      if (ref.mounted) state = AsyncData(next);
    } finally {
      turn.complete();
    }
  }

  Future<void> toggle(LibraryItem item) => _change((current) {
    final exists = current.contains(item.id);
    return LocalLibrary(
      items: exists
          ? current.items.where((value) => value.id != item.id).toList()
          : [...current.items, item],
      order: exists
          ? current.order.where((id) => id != item.id).toList()
          : [...current.order.where((id) => id != item.id), item.id],
    );
  });
  Future<void> setSpecial(LibraryKind kind, PlaceResult point) {
    if (kind != LibraryKind.home && kind != LibraryKind.work) {
      throw ArgumentError('Not a special place');
    }
    return _change(
      (current) => LocalLibrary(
        items: [
          ...current.items.where((item) => item.kind != kind),
          LibraryItem(
            id: kind.name,
            kind: kind,
            label: point.name,
            point: point,
          ),
        ],
        order: current.order.contains(kind.name)
            ? current.order
            : [...current.order, kind.name],
      ),
    );
  }

  Future<void> remove(String id) => _change(
    (current) => LocalLibrary(
      items: current.items.where((item) => item.id != id).toList(),
      order: current.order.where((value) => value != id).toList(),
    ),
  );
  Future<void> reorder(List<String> ids) => _change(
    (current) =>
        LocalLibrary(items: current.items, order: ids.toSet().toList()),
  );
}
