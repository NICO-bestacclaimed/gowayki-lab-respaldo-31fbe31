"""Verify the committed city payload bytes against their manifest."""
import hashlib
import json
from pathlib import Path


def main():
    root = Path(__file__).resolve().parent.parent / 'assets/city/arequipa'
    manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
    for name, expected in manifest['files'].items():
        content = (root / name).read_bytes()
        digest = hashlib.sha256(content).hexdigest()
        if len(content) != expected['bytes'] or digest != expected['sha256']:
            raise SystemExit(f'Invalid asset: {name} ({len(content)} bytes, {digest})')
        print(f'OK {name}: {len(content)} bytes, {digest}')


if __name__ == '__main__':
    main()
