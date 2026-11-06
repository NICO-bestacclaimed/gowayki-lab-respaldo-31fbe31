"""Verify bundled data, original artwork and SQLite native outputs in a debug APK."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
APK = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    manifest = json.loads((ROOT / 'assets/city/arequipa/manifest.json').read_text(encoding='utf-8'))
    artwork = json.loads((ROOT / 'tool/data/artwork_sources.json').read_text(encoding='utf-8'))
    official = {
        'armeabi-v7a': 'f33868d94e80992af137c7cf046a99406800f15434e289733cf472346be00ed4',
        'arm64-v8a': 'e684ef8646ffd48b95bae58bf29c55ffd85acebac2a7118ffde9fd02df37d629',
        'x86_64': 'ff28e78c5b790b3eafc15ceface32c3f5626ef80f622a726c60b0b802825699a',
    }
    with zipfile.ZipFile(APK) as apk:
        prefix = 'assets/flutter_assets/'
        assert apk.read(prefix+'assets/city/arequipa/manifest.json') == (ROOT/'assets/city/arequipa/manifest.json').read_bytes()
        for filename, info in manifest['files'].items():
            data = apk.read(prefix+'assets/city/arequipa/'+filename)
            assert len(data) == info['bytes'] and sha(data) == info['sha256'], filename
        for entry in artwork['files']:
            assert sha(apk.read(prefix+entry['asset'])) == entry['sha256'], entry['asset']
        assert not any('/assets/gtfs/' in name for name in apk.namelist())
        libraries = {}
        for abi, expected in official.items():
            merged = ROOT / f'build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/{abi}/libsqlite3.so'
            stripped = ROOT / f'build/app/intermediates/stripped_native_libs/debug/stripDebugDebugSymbols/out/lib/{abi}/libsqlite3.so'
            native = apk.read(f'lib/{abi}/libsqlite3.so')
            assert sha(merged.read_bytes()) == expected, abi
            assert native == stripped.read_bytes(), abi
            assert b'ENABLE_FTS5' in native, abi
            libraries[abi] = {'official_merged_hash': expected, 'apk_hash': sha(native), 'fts5': True}
    print(json.dumps({'apk': str(APK), 'apk_bytes': APK.stat().st_size, 'apk_sha256': sha(APK.read_bytes()),
        'data_version': manifest['version'], 'pack_sha256': manifest['sha256'], 'artwork_files_verified': len(artwork['files']),
        'payloads': 'verified', 'legacy_gtfs_assets': 'absent', 'sqlite_native': libraries}, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
