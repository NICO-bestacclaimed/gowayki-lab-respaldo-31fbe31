part of 'city_pack_installer.dart';

Future<String> _installedAppVersion() async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } on Object {
    return '1.0.0';
  }
}

/// Immutable directories keep existing readers usable while the active pointer changes.
extension CityPackUpdateStore on CityPackInstaller {
  Future<String> appVersion() => _appVersion();
  Future<Directory> updateRoot() async {
    final base = await _supportDirectory(),
        root = Directory(p.join(base.absolute.path, 'city', 'arequipa'));
    await root.create(recursive: true);
    return root;
  }

  Future<InstalledCityPack?> readActivePack(
    Directory root,
    CityPackManifest bundled,
  ) async {
    if (!await File(p.join(root.path, 'active.json')).exists() &&
        !await File(p.join(root.path, 'previous.json')).exists()) {
      return null;
    }
    semver.Version version;
    try {
      version = semver.Version.parse(await _appVersion());
    } on Object {
      return null;
    }
    for (final name in ['active.json', 'previous.json']) {
      try {
        final data =
            jsonDecode(await File(p.join(root.path, name)).readAsString())
                as Map<String, dynamic>;
        final directory = data['directory'] as String,
            minimum = data['minAppVersion'] as String;
        if (!RegExp(r'^[1-9][0-9]*-[a-f0-9]{64}$').hasMatch(directory) ||
            semver.Version.parse(minimum) > version) {
          continue;
        }
        final target = Directory(p.join(root.path, directory));
        final source = await File(
              p.join(target.path, 'manifest.json'),
            ).readAsString(),
            manifest = CityPackManifest.parse(source);
        if (directory != '${manifest.version}-${manifest.sha256}' ||
            data['sha256'] != manifest.sha256 ||
            data['version'] != manifest.version ||
            manifest.version < bundled.version ||
            (manifest.version == bundled.version &&
                manifest.compare(bundled) != CityPackVersionStatus.current)) {
          continue;
        }
        if (!await _isValid(target, source, manifest)) continue;
        await validateCityPackInBackground(p.join(target.path, 'pack.sqlite'));
        return InstalledCityPack(
          directory: target,
          manifest: manifest,
          minAppVersion: minimum,
        );
      } on Object {
        /* A corrupt/incompatible pointer never replaces a working bundle. */
      }
    }
    return null;
  }

  Future<bool> verifyUpdate(
    Directory directory,
    String source,
    CityPackManifest manifest,
  ) => _isValid(directory, source, manifest);
  Map<String, Object?> _descriptor(InstalledCityPack pack) => {
    'directory': p.basename(pack.directory.path),
    'version': pack.manifest.version,
    'sha256': pack.manifest.sha256,
    'minAppVersion': pack.minAppVersion,
  };
  void _directChild(Directory root, Directory child, {bool temporary = false}) {
    if (p.dirname(p.normalize(child.absolute.path)) !=
            p.normalize(root.absolute.path) ||
        (temporary && !p.basename(child.path).startsWith('download-'))) {
      throw const CityPackException('Directorio fuera del paquete.');
    }
  }

  Future<T> _updateLock<T>(Future<T> Function(Directory) action) async {
    final root = await updateRoot(),
        key = p.normalize(root.path),
        previous = CityPackInstaller._queues[key],
        turn = Completer<void>();
    CityPackInstaller._queues[key] = turn.future;
    if (previous != null) await previous;
    RandomAccessFile? lock;
    try {
      lock = await File(
        p.join(root.path, '.install.lock'),
      ).open(mode: FileMode.append);
      await lock.lock(FileLock.blockingExclusive);
      return await action(root);
    } finally {
      try {
        await lock?.close();
      } finally {
        turn.complete();
        if (identical(CityPackInstaller._queues[key], turn.future)) {
          CityPackInstaller._queues.remove(key);
        }
      }
    }
  }

  Future<void> _writePointer(
    Directory root,
    String name,
    Map<String, Object?> data,
  ) async {
    final file = File(p.join(root.path, '$name.next'));
    await file.writeAsString(jsonEncode(data), flush: true);
    await file.rename(p.join(root.path, name));
  }

  Future<InstalledCityPack> activateUpdate({
    required Directory stage,
    required String source,
    required CityPackManifest manifest,
    required String minimum,
    required InstalledCityPack previous,
  }) => _updateLock((root) async {
    _directChild(root, stage, temporary: true);
    _directChild(root, previous.directory);
    if (manifest.version <= previous.manifest.version ||
        semver.Version.parse(minimum) >
            semver.Version.parse(await _appVersion())) {
      throw const CityPackException('Versión incompatible.');
    }
    if (!await _isValid(stage, source, manifest)) {
      throw const CityPackException('Paquete descargado inválido.');
    }
    final target = Directory(
      p.join(root.path, '${manifest.version}-${manifest.sha256}'),
    );
    if (await target.exists()) {
      if (!await _isValid(target, source, manifest)) {
        _directChild(root, target);
        await target.rename(
          '${target.path}.invalid-${DateTime.now().microsecondsSinceEpoch}',
        );
      }
    }
    if (!await target.exists()) await stage.rename(target.path);
    final next = InstalledCityPack(
      directory: target,
      manifest: manifest,
      minAppVersion: minimum,
    );
    await _writePointer(root, 'previous.json', _descriptor(previous));
    await _writePointer(root, 'active.json', _descriptor(next));
    return next;
  });
  Future<void> rollbackUpdate(InstalledCityPack previous) =>
      _updateLock((root) async {
        _directChild(root, previous.directory);
        final source = await File(
          p.join(previous.directory.path, 'manifest.json'),
        ).readAsString();
        if (!await _isValid(previous.directory, source, previous.manifest)) {
          throw const CityPackException('Copia anterior inválida.');
        }
        await _writePointer(root, 'active.json', _descriptor(previous));
      });
}
