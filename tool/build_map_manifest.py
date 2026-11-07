"""Regenerate the local map manifest after a reviewed map/style/font change."""
from pathlib import Path
import argparse
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1] / 'assets/map'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    files = {p.relative_to(ROOT).as_posix(): {'bytes': p.stat().st_size,
        'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
        for p in sorted(ROOT.rglob('*')) if p.is_file() and p != ROOT / 'manifest.json'}
    manifest = {'schema_version': 1, 'city_code': 'arequipa', 'files': files}
    target = ROOT / 'manifest.json'
    if args.check:
        if json.loads(target.read_text(encoding='utf-8')) != manifest:
            raise SystemExit('Map manifest differs from local assets')
        print(f'Map manifest verified: {len(files)} files')
    else:
        target.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        print(f'Map manifest written: {len(files)} files')

if __name__ == '__main__':
    main()
