import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Publishes verified immutable map builds; never removes the previous build.
class OfflineMapPackage {
  const OfflineMapPackage({
    this.assetDir = 'assets/map',
    this.bundle,
    this.supportDirectory,
  });
  final String assetDir;
  final AssetBundle? bundle;
  final Future<Directory> Function()? supportDirectory;
  static final _queues = <String, Future<void>>{};

  Future<String> loadStyle({AssetBundle? bundle, bool dark = false}) async {
    final dir = await install(bundle: bundle);
    final style = await File(
      p.join(dir.path, dark ? 'style-dark.json' : 'style.json'),
    ).readAsString();
    return style.replaceAll('{MAP_DIR}', dir.path.replaceAll('\\', '/'));
  }

  Future<Directory> install({AssetBundle? bundle}) async {
    final assets = bundle ?? this.bundle ?? rootBundle;
    final source = await assets.loadString('$assetDir/manifest.json');
    final metadata = jsonDecode(source) as Map<String, dynamic>;
    if (metadata['schema_version'] != 1 ||
        metadata['city_code'] != 'arequipa') {
      throw const FormatException('Mapa incompatible');
    }
    final files = metadata['files'] as Map<String, dynamic>;
    if (!files.keys.toSet().containsAll([
      'arequipa.mbtiles',
      'style.json',
      'style-dark.json',
    ])) {
      throw const FormatException('Mapa incompleto');
    }
    for (final entry in files.entries) {
      final key = entry.key;
      final info = entry.value as Map<String, dynamic>;
      if (key.isEmpty ||
          key.contains('\\') ||
          key.contains(':') ||
          key.startsWith('/') ||
          key
              .split('/')
              .any((part) => part.isEmpty || part == '.' || part == '..') ||
          info['bytes'] is! int ||
          (info['bytes'] as int) <= 0 ||
          info['sha256'] is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(info['sha256'] as String)) {
        throw const FormatException('Archivo de mapa inválido');
      }
    }
    final base = await (supportDirectory ?? getApplicationSupportDirectory)();
    final root = Directory(p.join(base.absolute.path, 'map'));
    await root.create(recursive: true);
    final previous = _queues[root.path];
    final turn = Completer<void>();
    _queues[root.path] = turn.future;
    if (previous != null) await previous;
    try {
      return await _install(root, assets, source, files);
    } finally {
      turn.complete();
      if (identical(_queues[root.path], turn.future)) _queues.remove(root.path);
    }
  }

  Future<Directory> _install(
    Directory root,
    AssetBundle assets,
    String source,
    Map<String, dynamic> files,
  ) async {
    final lock = await File(
      p.join(root.path, '.install.lock'),
    ).open(mode: FileMode.append);
    Directory? stage;
    try {
      await lock.lock(FileLock.blockingExclusive);
      final digest = sha256.convert(utf8.encode(source)).toString();
      final target = Directory(p.join(root.path, digest));
      if (await target.exists() && await _valid(target, source, files)) {
        return target;
      }
      stage = await root.createTemp('install-');
      for (final entry in files.entries) {
        final data = await assets.load('$assetDir/${entry.key}');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        if (bytes.length != entry.value['bytes'] ||
            sha256.convert(bytes).toString() != entry.value['sha256']) {
          throw const FormatException('Mapa dañado');
        }
        final output = File(p.join(stage.path, entry.key));
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes, flush: true);
      }
      await File(
        p.join(stage.path, 'manifest.json'),
      ).writeAsString(source, flush: true);
      if (await target.exists()) {
        await target.rename(
          '${target.path}.invalid-${DateTime.now().microsecondsSinceEpoch}',
        );
      }
      final installed = await stage.rename(target.path);
      stage = null;
      return installed;
    } finally {
      try {
        if (stage != null && await stage.exists()) {
          if (p.dirname(p.normalize(stage.absolute.path)) !=
                  p.normalize(root.absolute.path) ||
              !p.basename(stage.path).startsWith('install-')) {
            throw StateError('Directorio temporal inválido');
          }
          await stage.delete(recursive: true);
        }
      } finally {
        await lock.close();
      }
    }
  }

  Future<bool> _valid(
    Directory target,
    String source,
    Map<String, dynamic> files,
  ) async {
    try {
      if (await File(p.join(target.path, 'manifest.json')).readAsString() !=
          source) {
        return false;
      }
      for (final entry in files.entries) {
        final file = File(p.join(target.path, entry.key));
        if (await file.length() != entry.value['bytes'] ||
            (await sha256.bind(file.openRead()).first).toString() !=
                entry.value['sha256']) {
          return false;
        }
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
