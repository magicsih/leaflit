import datetime as dt
import importlib.util
from pathlib import Path
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
        for offset in [-169, 2]:
            value = self.evidence()
            value['finishedUTC'] = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=offset)).isoformat()
            with self.assertRaises(ValueError): release.validate_evidence(value, 'candidate')

    def test_accepts_current_complete_evidence(self):
        release.validate_evidence(self.evidence(), 'candidate')

    def test_rejects_unaccepted_notarization_or_missing_id(self):
        for receipt in [{'id': 'submission', 'status': 'Invalid'}, {'status': 'Accepted'}]:
            with self.assertRaises(ValueError): release.validate_receipt(receipt)

    def test_accepts_notarization_receipt(self):
        self.assertEqual(release.validate_receipt({'id': 'submission', 'status': 'Accepted'}), 'submission')


if __name__ == '__main__':
    unittest.main()
