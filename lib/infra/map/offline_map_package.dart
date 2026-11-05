import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Copia MBTiles + style al almacenamiento interno (MapLibre no lee del APK).
class OfflineMapPackage {
  const OfflineMapPackage({
    this.assetDir = 'assets/map',
    this.version = 'arequipa-lab-2026-11',
    this.folderName = 'map',
  });

  final String assetDir;
  final String version;
  final String folderName;

  static const _placeholder = '{MAP_DIR}';

  Future<String> loadStyle({AssetBundle? bundle}) async {
    final dir = await install(bundle: bundle);
    final style = await File('${dir.path}/style.json').readAsString();
    return style.replaceAll(_placeholder, dir.path.replaceAll('\\', '/'));
  }

  Future<Directory> install({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$folderName');
    final marker = File('${dir.path}/.version');
    if (await marker.exists() && await marker.readAsString() == version) {
      return dir;
    }

    if (await dir.exists()) await dir.delete(recursive: true);
    final manifest = await AssetManifest.loadFromAssetBundle(b);
    final prefix = '$assetDir/';
    final assets = manifest.listAssets().where((a) => a.startsWith(prefix)).toList();
    if (assets.isEmpty) {
      throw StateError('No hay assets en $prefix');
    }

    for (final key in assets) {
      final data = await b.load(key);
      final out = File('${dir.path}/${key.substring(prefix.length)}');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    await marker.writeAsString(version, flush: true);
    return dir;
  }
}
