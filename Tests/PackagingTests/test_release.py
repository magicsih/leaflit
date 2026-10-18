import datetime as dt
import importlib.util
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('package_release', Path(__file__).parents[2] / 'scripts/package-release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseGateTests(unittest.TestCase):
    def evidence(self):
        return {'sourceSHA': 'candidate', 'result': 'passed',
                'finishedUTC': dt.datetime.now(dt.timezone.utc).isoformat(),
                'checks': ['npm test', 'npm audit --omit=dev', 'swift test', 'xcodebuild test', 'packaging tests']}

    def test_rejects_evidence_for_another_candidate(self):
        with self.assertRaises(ValueError):
            release.validate_evidence(self.evidence(), 'another-candidate')

    def test_rejects_failed_or_missing_checks(self):
        for status in ['failed', 'running']:
            value = self.evidence(); value['result'] = status
            with self.assertRaises(ValueError): release.validate_evidence(value, 'candidate')
        value = self.evidence(); value['checks'].remove('xcodebuild test')
        with self.assertRaises(ValueError): release.validate_evidence(value, 'candidate')

    def test_rejects_stale_or_future_evidence(self):
        for seconds in [-169 * 3600, 2 * 3600, 30]:
            value = self.evidence()
            value['finishedUTC'] = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(seconds=seconds)).isoformat()
            with self.assertRaises(ValueError): release.validate_evidence(value, 'candidate')

    def test_accepts_current_complete_evidence(self):
        release.validate_evidence(self.evidence(), 'candidate')

    def test_rejects_unaccepted_notarization_or_missing_id(self):
        for receipt in [{'id': 'submission', 'status': 'Invalid'}, {'status': 'Accepted'}]:
            with self.assertRaises(ValueError): release.validate_receipt(receipt)

    def test_accepts_notarization_receipt(self):
        self.assertEqual(release.validate_receipt({'id': 'submission', 'status': 'Accepted'}), 'submission')

    @unittest.skipUnless(sys.platform == 'darwin', 'Requires macOS code signing tools')
    def test_bundled_shell_launcher_survives_signing_and_zip_transfer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'Leaflit.app'
            executable = app / 'Contents/MacOS/Leaflit'
            executable.parent.mkdir(parents=True)
            shutil.copy('/usr/bin/true', executable)
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
                'CFBundleExecutable': 'Leaflit', 'CFBundleIdentifier': 'test.leaflit.packaging',
                'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1'}))
            helper = release.bundle_launcher(app)
            signing = subprocess.run(['codesign', '--force', '--sign', '-', str(app)],
                                     capture_output=True, text=True)
            self.assertEqual(signing.returncode, 0, signing.stderr)
            archive = root / 'app.zip'
            subprocess.run(['ditto', '-c', '-k', '--keepParent', str(app), str(archive)], check=True)
            extracted = root / 'extracted'
            subprocess.run(['ditto', '-x', '-k', str(archive), str(extracted)], check=True)
            restored = extracted / app.name
            subprocess.run(['codesign', '--verify', '--deep', '--strict', str(restored)],
                           capture_output=True, text=True, check=True)
            restored_helper = restored / helper.relative_to(app)
            self.assertEqual(restored_helper.read_bytes(), (release.ROOT / 'scripts/leaflit').read_bytes())
            self.assertTrue(restored_helper.stat().st_mode & 0o111)


if __name__ == '__main__':
    unittest.main()
