enum ReportKind { detour, missingStop, stopName, lineMissing, other }

extension ReportKindApi on ReportKind {
  String get apiValue => switch (this) {
    ReportKind.missingStop => 'missing_stop',
    ReportKind.stopName => 'stop_name',
    ReportKind.lineMissing => 'line_missing',
    _ => name,
  };
}

class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.uid,
    required this.kind,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.confirmations,
    this.stopId,
    this.lineId,
  });
  final String id, uid, description;
  final ReportKind kind;
  final double latitude, longitude;
  final DateTime createdAt;
  final int confirmations;
  final String? stopId, lineId;
  DateTime get expiresAt => createdAt.add(const Duration(hours: 72));
  bool activeAt(DateTime now) =>
      !createdAt.isAfter(now) && expiresAt.isAfter(now);
  Map<String, Object?> get feature => {
    'type': 'Feature',
    'id': id,
    'geometry': {
      'type': 'Point',
      'coordinates': [longitude, latitude],
    },
    'properties': {
      'id': id,
      'type': kind.apiValue,
      'confirmations': confirmations,
    },
  };
  factory CommunityReport.fromMap(String id, Map<String, dynamic> data) {
    final latitude = (data['latitude'] as num).toDouble(),
        longitude = (data['longitude'] as num).toDouble();
    final kind = ReportKind.values.firstWhere(
      (k) => k.apiValue == data['type'],
    );
    final description = data['description'] as String,
        uid = data['uid'] as String,
        createdAt = (data['createdAt'] as DateTime).toUtc(),
        count = data['confirmations'] as int;
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        uid.isEmpty ||
        description.length < 3 ||
        description.length > 500 ||
        count < 0) {
      throw const FormatException('Invalid report');
    }
    return CommunityReport(
      id: id,
      uid: uid,
      kind: kind,
      description: description,
      latitude: latitude,
      longitude: longitude,
      createdAt: createdAt,
      confirmations: count,
      stopId: data['stopId'] as String?,
      lineId: data['lineId'] as String?,
    );
  }
}

class ReportDraft {
  const ReportDraft({
    required this.id,
    required this.kind,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.stopId,
    this.lineId,
  });
  final String id, description;
  final ReportKind kind;
  final double latitude, longitude;
  final String? stopId, lineId;
  void validate() {
    if ((kind == ReportKind.lineMissing &&
            (lineId == null || lineId!.isEmpty)) ||
        description.trim().length < 3 ||
        description.trim().length > 500 ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        (stopId?.length ?? 0) > 128 ||
        (lineId?.length ?? 0) > 128) {
      throw const FormatException('Invalid report');
    }
  }
}

enum CommunityFailure { unavailable, needsAccount, expired, invalid }

class CommunityException implements Exception {
  const CommunityException(this.code);
  final CommunityFailure code;
}

class ReportFeed {
  const ReportFeed(this.items, {required this.fromCache});
  final List<CommunityReport> items;
  final bool fromCache;
}
