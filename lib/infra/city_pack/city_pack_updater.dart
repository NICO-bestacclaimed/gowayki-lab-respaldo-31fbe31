import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import '../../domain/updates/city_update.dart';
import 'city_pack_installer.dart';
import 'city_pack_manifest.dart';
import 'sqlite_city_pack_repository.dart';

class StagedCityUpdate {
  const StagedCityUpdate({
    required this.directory,
    required this.root,
    required this.source,
    required this.manifest,
    required this.minimum,
  });
  final Directory directory, root;
  final String source, minimum;
  final CityPackManifest manifest;
  Future<void> discard() async {
    if (!await directory.exists()) return;
    if (p.dirname(p.normalize(directory.absolute.path)) !=
            p.normalize(root.absolute.path) ||
        !p.basename(directory.path).startsWith('download-')) {
      throw const CityPackException('Directorio temporal fuera del paquete.');
    }
    await directory.delete(recursive: true);
  }
}

/// Downloads immutable builds to a private staging directory. It never edits
/// an open SQLite file or activates a candidate before all checks pass.
class CityPackUpdater {
  CityPackUpdater({required this.installer, this.allowLoopbackHttp = false});
  final CityPackInstaller installer;
  final bool allowLoopbackHttp;
  HttpClient? _client;
  bool _cancelled = false;
  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }

  bool shouldDownload(
    CityUpdateMetadata metadata,
    InstalledCityPack current,
    String appVersion,
  ) {
    try {
      if (metadata.version == current.manifest.version &&
          metadata.sha256 != current.manifest.sha256) {
        throw const CityUpdateException(UpdateProblem.conflict);
      }
      if (metadata.version <= current.manifest.version) return false;
      if (Version.parse(metadata.minAppVersion) > Version.parse(appVersion)) {
        throw const CityUpdateException(UpdateProblem.incompatibleApp);
      }
      if (metadata.dataUrl == null) {
        throw const CityUpdateException(UpdateProblem.unavailable);
      }
      _uri(metadata.dataUrl!);
      return true;
    } on CityUpdateException {
      rethrow;
    } on Object {
      throw const CityUpdateException(UpdateProblem.invalidMetadata);
    }
  }

  void _uri(Uri uri) {
    final loopback = ['127.0.0.1', 'localhost', '::1'].contains(uri.host);
    if (uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery ||
        uri.host.isEmpty ||
        uri.pathSegments.contains('..') ||
        (uri.scheme != 'https' &&
            !(allowLoopbackHttp && loopback && uri.scheme == 'http'))) {
      throw const CityUpdateException(UpdateProblem.invalidMetadata);
    }
  }

  Future<HttpClientResponse> _get(Uri uri) async {
    for (var hop = 0; hop < 4; hop++) {
      if (_cancelled) throw const CityUpdateException(UpdateProblem.cancelled);
      _uri(uri);
      final request = await _client!.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close();
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null) {
          throw const CityUpdateException(UpdateProblem.download);
        }
        uri = uri.resolve(location);
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw const CityUpdateException(UpdateProblem.download);
      }
      return response;
    }
    throw const CityUpdateException(UpdateProblem.download);
  }

  Future<StagedCityUpdate> download(
    CityUpdateMetadata metadata, {
    void Function(int received, int total)? progress,
  }) async {
    _cancelled = false;
    final root = await installer.updateRoot(),
        stage = await root.createTemp('download-');
    StagedCityUpdate? result;
    _client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 15);
    final deadline = Timer(const Duration(minutes: 3), () {
      _client?.close(force: true);
    });
    try {
      final url = metadata.dataUrl;
      if (url == null || url.pathSegments.lastOrNull != 'pack.sqlite') {
        throw const CityUpdateException(UpdateProblem.invalidMetadata);
      }
      final response = await _get(url.resolve('manifest.json'));
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes.addAll(chunk);
        if (bytes.length > 1024 * 1024) {
          throw const CityUpdateException(UpdateProblem.invalidMetadata);
        }
      }
      final source = utf8.decode(bytes),
          manifest = CityPackManifest.parse(source);
      if (manifest.version != metadata.version ||
          manifest.sha256 != metadata.sha256 ||
          manifest.files['pack.sqlite']!.bytes != metadata.bytes) {
        throw const CityUpdateException(UpdateProblem.integrity);
      }
      final total = manifest.files.values.fold(
        0,
        (sum, file) => sum + file.bytes,
      );
      if (total > 96 * 1024 * 1024) {
        throw const CityUpdateException(UpdateProblem.invalidMetadata);
      }
      var received = 0;
      var previous = DateTime.fromMillisecondsSinceEpoch(0);
      for (final entry in manifest.files.entries) {
        final response = await _get(url.resolve(entry.key)),
            sink = File(p.join(stage.path, entry.key)).openWrite();
        var count = 0;
        try {
          await for (final chunk in response.timeout(
            const Duration(seconds: 30),
          )) {
            if (_cancelled) {
              throw const CityUpdateException(UpdateProblem.cancelled);
            }
            count += chunk.length;
            received += chunk.length;
            if (count > entry.value.bytes) {
              throw const CityUpdateException(UpdateProblem.integrity);
            }
            sink.add(chunk);
            final now = DateTime.now();
            if (now.difference(previous).inMilliseconds >= 100) {
              progress?.call(received, total);
              previous = now;
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        if (count != entry.value.bytes) {
          throw const CityUpdateException(UpdateProblem.integrity);
        }
      }
      await File(
        p.join(stage.path, 'manifest.json'),
      ).writeAsString(source, flush: true);
      if (!await installer.verifyUpdate(stage, source, manifest)) {
        throw const CityUpdateException(UpdateProblem.integrity);
      }
      final path = p.join(stage.path, 'pack.sqlite');
      await validateCityPackInBackground(path);
      // Probe the tables, geometry, search/map data and RAPTOR input before publishing.
      final probe = SqliteCityPackRepository.openInstalled(
        InstalledCityPack(
          directory: stage,
          manifest: manifest,
          minAppVersion: metadata.minAppVersion,
        ),
      );
      try {
        await probe.lines();
        await probe.mapStops();
        await probe.plannerNetwork();
      } finally {
        await probe.close();
      }
      if (_cancelled) throw const CityUpdateException(UpdateProblem.cancelled);
      progress?.call(total, total);
      result = StagedCityUpdate(
        directory: stage,
        root: root,
        source: source,
        manifest: manifest,
        minimum: metadata.minAppVersion,
      );
      return result;
    } on CityUpdateException {
      rethrow;
    } on CityPackException {
      throw const CityUpdateException(UpdateProblem.integrity);
    } on Object {
      throw CityUpdateException(
        _cancelled ? UpdateProblem.cancelled : UpdateProblem.download,
      );
    } finally {
      deadline.cancel();
      _client?.close(force: true);
      _client = null;
      if (result == null) {
        if (p.dirname(p.normalize(stage.absolute.path)) !=
                p.normalize(root.absolute.path) ||
            !p.basename(stage.path).startsWith('download-')) {
          throw const CityPackException(
            'Directorio temporal fuera del paquete.',
          );
        }
        if (await stage.exists()) await stage.delete(recursive: true);
      }
    }
  }
}
