"""Inspect the compiled APK: foreground location service, notification access, no background permission."""
from pathlib import Path
import json
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
APK = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'

def main():
    sdk = Path(os.environ['ANDROID_HOME'])
    aapt = sorted((sdk/'build-tools').glob('*/aapt.exe'))[-1]
    def dump(*args):
        return subprocess.check_output([str(aapt), 'dump', *args], encoding='utf-8', errors='replace')
    permissions = dump('permissions', str(APK))
    required = ['ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'FOREGROUND_SERVICE',
        'FOREGROUND_SERVICE_LOCATION', 'POST_NOTIFICATIONS', 'WAKE_LOCK']
    for name in required:
        assert "name='android.permission." + name + "'" in permissions, name
    assert 'ACCESS_BACKGROUND_LOCATION' not in permissions
    xml = dump('xmltree', str(APK), 'AndroidManifest.xml')
    lines = xml.splitlines()
    blocks = []
    for i, line in enumerate(lines):
        if line.lstrip().startswith('E: service '):
            indent = len(line) - len(line.lstrip())
            end = i + 1
            while end < len(lines):
                next_line = lines[end]
                if next_line.strip() and len(next_line) - len(next_line.lstrip()) <= indent:
                    break
                end += 1
            blocks.append('\n'.join(lines[i:end]))
    service = next(b for b in blocks if 'com.baseflow.geolocator.GeolocatorLocationService' in b)
    assert 'android:foregroundServiceType' in service and '0x8' in service
    assert 'android:stopWithTask' in service and '0xffffffff' in service
    assert 'android:exported' in service and '0x0' in service
    print(json.dumps({'required_permissions': required, 'background_location_permission': 'absent',
        'location_service_type': 'location', 'service_stop_with_task': True,
        'service_exported': False, 'physical_runtime': 'not tested'}, indent=2))

if __name__ == '__main__':
    main()
