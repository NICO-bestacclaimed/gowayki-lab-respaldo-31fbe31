import 'dart:convert';

class CityPackException implements Exception {
  const CityPackException(this.message);
  final String message;
  @override
  String toString() => 'CityPackException: $message';
}

enum CityPackVersionStatus {
  current,
  updateAvailable,
  localNewer,
  differentBuild,
}

class CityPackFile {
  const CityPackFile({required this.bytes, required this.sha256});
  final int bytes;
  final String sha256;
}

/// Describes one immutable build. Hashes detect corruption, not authenticity.
class CityPackManifest {
  CityPackManifest._(this.version, this.sha256, this.generatedAt, this.files);
  final int version;
  final String sha256;
  final DateTime generatedAt;
  final Map<String, CityPackFile> files;
  static final _hash = RegExp(r'^[0-9a-f]{64}$');

  factory CityPackManifest.parse(String source) {
    try {
      final m = jsonDecode(source) as Map<String, dynamic>;
      if (m['schema_version'] != 1 || m['city_code'] != 'arequipa') {
        throw const CityPackException(
          'Ciudad o esquema de datos incompatible.',
        );
      }
      final version = m['version'];
      if (version is! int || version < 1) {
        throw const CityPackException('Versión de datos inválida.');
      }
      final entries = m['files'] as Map<String, dynamic>;
      if (entries.length != 2 ||
          !entries.containsKey('pack.sqlite') ||
          !entries.containsKey('routes.geojson')) {
        throw const CityPackException('Archivos del paquete inválidos.');
      }
      final files = <String, CityPackFile>{};
      for (final entry in entries.entries) {
        final info = entry.value as Map<String, dynamic>;
        final bytes = info['bytes'];
        final hash = info['sha256'];
        if (bytes is! int ||
            bytes <= 0 ||
            hash is! String ||
            !_hash.hasMatch(hash)) {
          throw const CityPackException('Tamaño o SHA-256 inválido.');
        }
        files[entry.key] = CityPackFile(bytes: bytes, sha256: hash);
      }
      if (m['sha256'] != files['pack.sqlite']!.sha256 ||
          m['size_bytes'] != files['pack.sqlite']!.bytes) {
        throw const CityPackException('Manifiesto inconsistente.');
      }
      return CityPackManifest._(
        version,
        m['sha256'] as String,
        DateTime.parse(m['generated_at'] as String),
        Map.unmodifiable(files),
      );
    } on CityPackException {
      rethrow;
    } on Object {
      throw const CityPackException(
        'No se pudo leer el manifiesto del paquete.',
      );
    }
  }

  CityPackVersionStatus compare(CityPackManifest candidate) {
    if (candidate.version > version) {
      return CityPackVersionStatus.updateAvailable;
    }
    if (candidate.version < version) return CityPackVersionStatus.localNewer;
    if (candidate.sha256 != sha256 ||
        candidate.files['routes.geojson']!.sha256 !=
            files['routes.geojson']!.sha256) {
      return CityPackVersionStatus.differentBuild;
    }
    return CityPackVersionStatus.current;
  }
}
