"""Client regeneration must not remove deployment safeguards."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


class ConfigureFirebaseTest(unittest.TestCase):
    def test_preserves_hosting_and_emulator_configuration(self):
        spec = importlib.util.spec_from_file_location('configure_firebase', ROOT / 'tool/configure_firebase.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for name in ['firebase.json', 'android/app/google-services.json',
                         'ios/Runner/GoogleService-Info.plist', 'ios/Runner/Info.plist']:
                destination = target / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, destination)
            for name in ['lib', 'docs']:
                (target / name).mkdir()
            before = json.loads((target / 'firebase.json').read_text())
            module.ROOT = target
            with patch('sys.argv', ['configure_firebase.py', '--require-google']):
                module.main()
            after = json.loads((target / 'firebase.json').read_text())
            self.assertEqual(before['hosting'], after['hosting'])
            self.assertEqual(before['emulators'], after['emulators'])
            self.assertIn('node tool/check_hosting.mjs', after['hosting']['predeploy'])


if __name__ == '__main__':
    unittest.main()
