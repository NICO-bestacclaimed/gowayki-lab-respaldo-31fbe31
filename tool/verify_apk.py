"""Verify bundled data, original artwork and SQLite native outputs in a debug or release APK."""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
APK = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk',type=Path,default=APK)
    parser.add_argument('--variant',choices=['debug','release'],default='debug')
    args=parser.parse_args()
    artifact=args.apk.resolve()
    variant=args.variant
    task=variant.capitalize()
    manifest = json.loads((ROOT / 'assets/city/arequipa/manifest.json').read_text(encoding='utf-8'))
    artwork = json.loads((ROOT / 'tool/data/artwork_sources.json').read_text(encoding='utf-8'))
    map_manifest = json.loads((ROOT / 'assets/map/manifest.json').read_text(encoding='utf-8'))
    official = {
        'armeabi-v7a': 'f33868d94e80992af137c7cf046a99406800f15434e289733cf472346be00ed4',
        'arm64-v8a': 'e684ef8646ffd48b95bae58bf29c55ffd85acebac2a7118ffde9fd02df37d629',
        'x86_64': 'ff28e78c5b790b3eafc15ceface32c3f5626ef80f622a726c60b0b802825699a',
    }
    with zipfile.ZipFile(artifact) as apk:
        prefix = 'assets/flutter_assets/'
        assert apk.read(prefix+'assets/city/arequipa/manifest.json') == (ROOT/'assets/city/arequipa/manifest.json').read_bytes()
        for filename, info in manifest['files'].items():
            data = apk.read(prefix+'assets/city/arequipa/'+filename)
            assert len(data) == info['bytes'] and sha(data) == info['sha256'], filename
        for entry in artwork['files']:
            assert sha(apk.read(prefix+entry['asset'])) == entry['sha256'], entry['asset']
        assert apk.read(prefix+'assets/map/manifest.json') == (ROOT/'assets/map/manifest.json').read_bytes()
        for name, info in map_manifest['files'].items():
            # Flutter stores asset paths as URI paths (font directories contain spaces).
            data = apk.read(prefix+quote('assets/map/'+name, safe='/'))
            assert len(data) == info['bytes'] and sha(data) == info['sha256'], name
        assert not any('/assets/gtfs/' in name for name in apk.namelist())
        game_files = sorted(p for p in (ROOT/'assets/game').rglob('*') if p.is_file())
        game_bytes = sum(p.stat().st_size for p in game_files)
        assert 0 < game_bytes < 150000
        for path in game_files:
            name = path.relative_to(ROOT).as_posix()
            assert apk.read(prefix+name) == path.read_bytes(), name
        libraries = {}
        for abi, expected in official.items():
            merged = ROOT / f'build/app/intermediates/merged_native_libs/{variant}/merge{task}NativeLibs/out/lib/{abi}/libsqlite3.so'
            stripped = ROOT / f'build/app/intermediates/stripped_native_libs/{variant}/strip{task}DebugSymbols/out/lib/{abi}/libsqlite3.so'
            native = apk.read(f'lib/{abi}/libsqlite3.so')
            assert sha(merged.read_bytes()) == expected, abi
            assert native == stripped.read_bytes(), abi
            assert b'ENABLE_FTS5' in native, abi
            libraries[abi] = {'official_merged_hash': expected, 'apk_hash': sha(native), 'fts5': True}
    print(json.dumps({'apk': str(artifact), 'variant':variant, 'apk_bytes': artifact.stat().st_size, 'apk_sha256': sha(artifact.read_bytes()),
        'data_version': manifest['version'], 'pack_sha256': manifest['sha256'], 'artwork_files_verified': len(artwork['files']),
        'map_files_verified': len(map_manifest['files']), 'game_files_verified': len(game_files), 'game_total_bytes': game_bytes, 'payloads': 'verified', 'legacy_gtfs_assets': 'absent', 'sqlite_native': libraries}, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
