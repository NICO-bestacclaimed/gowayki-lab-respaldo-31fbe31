enum UpdateProblem {
  unavailable,
  invalidMetadata,
  incompatibleApp,
  conflict,
  download,
  integrity,
  cancelled,
  activeTrip,
  busy,
  activation,
}

class CityUpdateException implements Exception {
  const CityUpdateException(this.problem);
  final UpdateProblem problem;
  @override
  String toString() => 'CityUpdateException(${problem.name})';
}

class CityUpdateMetadata {
  const CityUpdateMetadata({
    required this.version,
    required this.sha256,
    required this.bytes,
    this.dataUrl,
    this.minAppVersion = '0.0.0',
  });
  final int version, bytes;
  final String sha256, minAppVersion;
  final Uri? dataUrl;
  factory CityUpdateMetadata.fromJson(Map<String, dynamic> data) {
    final version = data['dataVersion'],
        hash = data['dataSha256'],
        bytes = data['dataBytes'],
        minimum = data['minAppVersion'] ?? '0.0.0',
        url = data['dataUrl'];
    if (version is! int ||
        version < 1 ||
        version > 1000000 ||
        hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        bytes is! int ||
        bytes < 1 ||
        bytes > 64 * 1024 * 1024 ||
        minimum is! String ||
        (url != null && url is! String)) {
      throw const CityUpdateException(UpdateProblem.invalidMetadata);
    }
    return CityUpdateMetadata(
      version: version,
      sha256: hash,
      bytes: bytes,
      minAppVersion: minimum,
      dataUrl: url == null ? null : Uri.parse(url),
    );
  }
}

abstract interface class CityUpdateRepository {
  Future<CityUpdateMetadata?> check();
}
