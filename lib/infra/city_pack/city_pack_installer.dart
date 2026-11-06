import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'city_pack_manifest.dart';

class InstalledCityPack {
  const InstalledCityPack({required this.directory, required this.manifest});
  final Directory directory;
  final CityPackManifest manifest;
  String get databasePath => p.join(directory.path, 'pack.sqlite');
}

/// Installs the bundled build only. Network updates belong to Part 9.
class CityPackInstaller {
  CityPackInstaller({
    AssetBundle? bundle,
    Future<Directory> Function()? supportDirectory,
    this.assetDirectory = 'assets/city/arequipa',
  }) : _bundle = bundle ?? rootBundle,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final AssetBundle _bundle;
  final Future<Directory> Function() _supportDirectory;
  final String assetDirectory;
  static final _queues = <String, Future<void>>{};

  Future<InstalledCityPack> install() async {
    final source = await _bundle.loadString('$assetDirectory/manifest.json');
    final manifest = CityPackManifest.parse(source);
    final base = await _supportDirectory();
    final root = Directory(p.join(base.absolute.path, 'city', 'arequipa'));
    await root.create(recursive: true);
    // Serialize callers in this isolate; also take an OS file lock.
    final key = p.normalize(root.path);
    final previous = _queues[key] ?? Future<void>.value();
    final turn = Completer<void>();
    _queues[key] = turn.future;
    await previous;
    try {
      return await _installLocked(root, source, manifest);
    } finally {
      turn.complete();
      if (identical(_queues[key], turn.future)) _queues.remove(key);
    }
  }

  Future<InstalledCityPack> _installLocked(
    Directory root,
    String source,
    CityPackManifest manifest,
  ) async {
    final lock = await File(
      p.join(root.path, '.install.lock'),
    ).open(mode: FileMode.append);
    Directory? stage;
    try {
      await lock.lock(FileLock.blockingExclusive);
      final target = Directory(
        p.join(root.path, '${manifest.version}-${manifest.sha256}'),
      );
      if (await target.exists() && await _isValid(target, source, manifest)) {
        return InstalledCityPack(directory: target, manifest: manifest);
      }
      stage = await root.createTemp('install-');
      for (final entry in manifest.files.entries) {
        final data = await _bundle.load('$assetDirectory/${entry.key}');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        if (bytes.length != entry.value.bytes) {
          throw CityPackException('Tamaño incorrecto: ${entry.key}.');
        }
        await File(
          p.join(stage.path, entry.key),
        ).writeAsBytes(bytes, flush: true);
      }
      await File(
        p.join(stage.path, 'manifest.json'),
      ).writeAsString(source, flush: true);
      if (!await _isValid(stage, source, manifest)) {
        throw const CityPackException(
          'El paquete no superó la verificación SHA-256.',
        );
      }
      final stageDatabase = p.join(stage.path, 'pack.sqlite');
      await Isolate.run(() => validateCityPackDatabase(stageDatabase));
      // Existing versions remain untouched. Preserve a corrupt build for diagnosis.
      if (await target.exists()) {
        await target.rename(
          '${target.path}.invalid-${DateTime.now().microsecondsSinceEpoch}',
        );
      }
      await stage.rename(target.path);
      stage = null;
      return InstalledCityPack(directory: target, manifest: manifest);
    } finally {
      try {
        if (stage != null && await stage.exists()) {
          // Only remove our staging directory created directly under root.
          if (p.dirname(p.normalize(stage.absolute.path)) !=
                  p.normalize(root.absolute.path) ||
              !p.basename(stage.path).startsWith('install-')) {
            throw const CityPackException(
              'Directorio temporal fuera del paquete.',
            );
          }
          await stage.delete(recursive: true);
        }
      } finally {
        // Release the OS lock even when filesystem cleanup itself fails.
        await lock.close();
      }
    }
  }

  Future<bool> _isValid(
    Directory directory,
    String source,
    CityPackManifest manifest,
  ) async {
    try {
      if (await File(p.join(directory.path, 'manifest.json')).readAsString() !=
          source) {
        return false;
      }
      for (final entry in manifest.files.entries) {
        final file = File(p.join(directory.path, entry.key));
        if (await file.length() != entry.value.bytes) return false;
        final name = file.path;
        final hash = await Isolate.run(
          () async =>
              (await sha256.bind(File(name).openRead()).first).toString(),
        );
        if (hash != entry.value.sha256) return false;
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }
}

/// Runs once before publishing a new install, including an actual FTS5 query.
void validateCityPackDatabase(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    if (db.select('PRAGMA quick_check').single.values.single != 'ok' ||
        db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw const CityPackException('Integridad SQLite inválida.');
    }
    if (db.select('SELECT city_code FROM cities').single['city_code'] !=
        'arequipa') {
      throw const CityPackException('Ciudad SQLite incompatible.');
    }
    // Verify the tables consumed by the repository, not just a readable header.
    db.select('SELECT line_id,name,color FROM lines LIMIT 1');
    db.select('SELECT pattern_id,line_id,shape_id FROM patterns LIMIT 1');
    db.select('SELECT stop_sequence,distance_m FROM pattern_stops LIMIT 1');
    db.select('SELECT stop_id,name,source_kind FROM stops LIMIT 1');
    db.select('SELECT key,value_json FROM config LIMIT 1');
    if (db.select('SELECT rowid FROM places_fts WHERE places_fts MATCH ?', [
      '"tecsup"*',
    ]).isEmpty) {
      throw const CityPackException(
        'El paquete no contiene la búsqueda FTS esperada.',
      );
    }
  } finally {
    db.close();
  }
}
