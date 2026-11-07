import 'dart:convert';

/// Per-item last-writer-wins register. Null values are deletion markers.
/// Ties use an installation ID; clocks advance beyond every observed stamp.
class PersonalRecord {
  PersonalRecord({
    required this.key,
    required this.stamp,
    required this.device,
    required Object? value,
  }) : value = _freeze(jsonDecode(jsonEncode(value)));
  static dynamic _freeze(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key as String, _freeze(item))),
      );
    }
    if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
    return value;
  }

  final String key, device;
  final int stamp;
  final dynamic value;
  Map<String, Object?> toJson() => {
    'key': key,
    'stamp': stamp,
    'device': device,
    'value': value,
  };
  factory PersonalRecord.fromJson(Map<String, dynamic> data) {
    final key = data['key'], stamp = data['stamp'], device = data['device'];
    if (key is! String ||
        key.isEmpty ||
        key.length > 1500 ||
        stamp is! int ||
        stamp < 0 ||
        device is! String ||
        device.length > 128 ||
        !data.containsKey('value') ||
        jsonEncode(data).length > 100000) {
      throw const FormatException('Invalid personal record');
    }
    return PersonalRecord(
      key: key,
      stamp: stamp,
      device: device,
      value: data['value'],
    );
  }
  int compareTo(PersonalRecord other) {
    final time = stamp.compareTo(other.stamp);
    if (time != 0) return time;
    final installation = device.compareTo(other.device);
    if (installation != 0) return installation;
    // Stable even if a malformed client reuses a revision.
    return jsonEncode(value).compareTo(jsonEncode(other.value));
  }

  static Map<String, PersonalRecord> merge(
    Iterable<PersonalRecord> a,
    Iterable<PersonalRecord> b,
  ) {
    final result = {for (final record in a) record.key: record};
    for (final record in b) {
      final old = result[record.key];
      if (old == null || record.compareTo(old) > 0) result[record.key] = record;
    }
    return Map.unmodifiable(result);
  }
}

class PersonalSnapshot {
  PersonalSnapshot(Iterable<PersonalRecord> records)
    : records = Map.unmodifiable({for (final r in records) r.key: r});
  final Map<String, PersonalRecord> records;
  dynamic value(String key) => records[key]?.value;
  int get clock =>
      records.values.fold(0, (value, r) => r.stamp > value ? r.stamp : value);
  String encode() => jsonEncode({
    'version': 1,
    'records': records.values.map((r) => r.toJson()).toList(),
  });
  factory PersonalSnapshot.decode(String text) {
    final data = jsonDecode(text);
    if (data is! Map || data['version'] != 1 || data['records'] is! List) {
      throw const FormatException('Invalid personal snapshot');
    }
    return PersonalSnapshot(
      (data['records'] as List).map(
        (r) => PersonalRecord.fromJson(Map<String, dynamic>.from(r)),
      ),
    );
  }
}
