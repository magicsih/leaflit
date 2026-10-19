#!/usr/bin/env python3
"""Prepare and finalize an immutable Developer ID distribution.

Notarization credentials are supplied only to notarytool by the operator.
This script never reads, stores or prints a private key or password.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
VERSION = plistlib.loads((ROOT / 'Sources/Leaflit/Info.plist').read_bytes())['CFBundleShortVersionString']


def run(*args):
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True, check=True)
    return result.stdout + result.stderr


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def validate_evidence(evidence, source_sha):
    required = {'npm test', 'npm audit --omit=dev', 'swift test', 'xcodebuild test', 'packaging tests'}
    if evidence.get('sourceSHA') != source_sha or evidence.get('result') != 'passed':
        raise ValueError('Verification must pass on the exact candidate SHA')
    if not required.issubset(set(evidence.get('checks', []))):
        raise ValueError('The complete release verification is missing')
    finished = dt.datetime.fromisoformat(evidence['finishedUTC'].replace('Z', '+00:00'))
    hours = (dt.datetime.now(dt.timezone.utc) - finished).total_seconds() / 3600
    if not 0 <= hours <= 168:
        raise ValueError('Verification is stale or dated in the future')


def validate_receipt(receipt):
    if receipt.get('status') != 'Accepted' or not receipt.get('id'):
        raise ValueError('An Accepted Apple notarization receipt with a submission ID is required')
    return receipt['id']


def signature(app, team_id):
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', app)
    details = run('/usr/bin/codesign', '--display', '--verbose=4', app)
    if ('Authority=Developer ID Application:' not in details or
            f'TeamIdentifier={team_id}' not in details or '(runtime)' not in details):
        raise ValueError('Developer ID, team identity or hardened runtime verification failed')
    return details


def bundle_launcher(app):
    helper = app / 'Contents/Resources/leaflit'
    helper.parent.mkdir(exist_ok=True)
    shutil.copy2(ROOT / 'scripts/leaflit', helper)
    helper.chmod(0o755)
    return helper


def prepare(args):
    source_sha = run('git', 'rev-parse', 'HEAD').strip()
    if run('git', 'status', '--porcelain').strip():
        raise ValueError('Commit the release candidate before packaging')
    evidence = json.loads((ROOT / 'build/verification.json').read_text())
    validate_evidence(evidence, source_sha)
    build = ROOT / f'build/Leaflit-{VERSION}'
    info = json.loads((build / 'build-info.json').read_text())
    if info['sourceSHA'] != source_sha:
        raise ValueError('The clean Release build must match the verified candidate')
    source = build / 'Leaflit.app'
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', source)
    if sha256(source / 'Contents/MacOS/Leaflit') != info['binarySHA256']:
        raise ValueError('The candidate executable differs from its build record')
    bundle = plistlib.loads((source / 'Contents/Info.plist').read_bytes())
    version = bundle['CFBundleShortVersionString']
    if bundle['CFBundleIdentifier'] != 'io.github.magicsih.leaflit' or version != VERSION:
        raise ValueError('Unexpected bundle identity or version')
    if run('/usr/bin/lipo', '-archs', source / 'Contents/MacOS/Leaflit').strip() != 'arm64':
        raise ValueError('Only the verified Apple Silicon architecture is supported')
    args.out.mkdir(parents=True, exist_ok=False)
    payload = args.out / f'Leaflit-{version}'
    payload.mkdir()
    app = payload / 'Leaflit.app'
    run('/usr/bin/ditto', source, app)
    bundle_launcher(app)
    shutil.copy2(ROOT / 'scripts/leaflit', payload / 'leaflit')
    shutil.copy2(ROOT / 'LICENSE', payload / 'LICENSE')
    (payload / 'README.txt').write_text(
        f'Leaflit {version} for Apple Silicon\n\n'
        'Move Leaflit.app to Applications and open it. Keep the standalone leaflit\n'
        'launcher beside the app, or use the launcher inside Contents/Resources.\n'
        'Homebrew also installs the app and command:\n'
        '  brew install --cask magicsih/tap/leaflit\n\n'
        'Documentation and known limitations: https://github.com/magicsih/leaflit\n')
    frameworks = list((app / 'Contents/Frameworks').glob('*.framework'))
    if len(frameworks) != 1 or frameworks[0].name != 'LeaflitCore.framework':
        raise ValueError('Unexpected nested code; review signing coverage before proceeding')
    for code in frameworks + [app]:
        run('/usr/bin/codesign', '--force', '--options', 'runtime', '--timestamp',
            '--sign', args.identity, code)
    details = signature(app, args.team_id)
    (args.out / 'signature.txt').write_text(details)
    info.update({'binarySHA256': sha256(app / 'Contents/MacOS/Leaflit'),
                 'signing': 'Developer ID with hardened runtime', 'teamId': args.team_id})
    write_json(payload / 'build-info.json', info)
    upload = args.out / 'notarization-upload.zip'
    run('/usr/bin/ditto', '-c', '-k', '--keepParent', payload, upload)
    state = {'version': version, 'sourceSHA': source_sha, 'bundleId': bundle['CFBundleIdentifier'],
             'architecture': 'arm64', 'minimumOS': bundle['LSMinimumSystemVersion'],
             'teamId': args.team_id, 'binarySHA256': info['binarySHA256'],
             'uploadSHA256': sha256(upload), 'status': 'signed-awaiting-notarization',
             'preparedUTC': dt.datetime.now(dt.timezone.utc).isoformat()}
    write_json(args.out / 'state.json', state)
    print(f'Signed candidate: {app}')
    print(f'Notarization upload: {upload}')


def finalize(args):
    state = json.loads((args.out / 'state.json').read_text())
    receipt = json.loads(args.receipt.read_text())
    submission = validate_receipt(receipt)
    if state['sourceSHA'] != run('git', 'rev-parse', 'HEAD').strip():
        raise ValueError('The candidate SHA changed after preparation')
    if run('git', 'status', '--porcelain').strip():
        raise ValueError('The candidate worktree changed after preparation')
    payload = args.out / f"Leaflit-{state['version']}"
    app = payload / 'Leaflit.app'
    archive = args.out / f"Leaflit-{state['version']}-macos-arm64.zip"
    if state['status'] == 'ready':
        if state['notarization']['id'] != submission or sha256(archive) != state['archiveSHA256']:
            raise ValueError('The existing immutable artifact does not match')
        print(f'Existing verified archive: {archive}')
        return
    if archive.exists():
        raise FileExistsError('Refusing to replace an existing distribution archive')
    if sha256(args.out / 'notarization-upload.zip') != state['uploadSHA256']:
        raise ValueError('The notarization upload archive changed')
    if sha256(app / 'Contents/MacOS/Leaflit') != state['binarySHA256']:
        raise ValueError('The signed executable changed')
    staple = run('xcrun', 'stapler', 'staple', app)
    staple += run('xcrun', 'stapler', 'validate', app)
    (args.out / 'stapling.txt').write_text(staple)
    signature(app, state['teamId'])
    assessment = run('/usr/sbin/spctl', '--assess', '--type', 'execute', '--verbose=4', app)
    (args.out / 'gatekeeper.txt').write_text(assessment)
    run('/usr/bin/ditto', '-c', '-k', '--keepParent', payload, archive)
    state.update({'status': 'ready', 'archiveSHA256': sha256(archive),
                  'archiveName': archive.name, 'notarization': {'id': submission, 'status': 'Accepted'},
                  'stapled': True, 'gatekeeper': 'accepted',
                  'finalizedUTC': dt.datetime.now(dt.timezone.utc).isoformat()})
    write_json(args.out / 'state.json', state)
    write_json(args.out / 'release-manifest.json', state)
    (args.out / 'SHA256SUMS').write_text(f"{state['archiveSHA256']}  {archive.name}\n")
    print(f'Verified immutable archive: {archive}')
    print(f"SHA256: {state['archiveSHA256']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=ROOT / f'build/releases/{VERSION}')
    commands = parser.add_subparsers(dest='command', required=True)
    signing = commands.add_parser('prepare')
    signing.add_argument('--identity', required=True, help='Existing public Developer ID identity or fingerprint')
    signing.add_argument('--team-id', required=True, help='Expected public Apple team ID')
    finishing = commands.add_parser('finalize')
    finishing.add_argument('--receipt', type=Path, required=True, help='Accepted notarytool JSON receipt')
    args = parser.parse_args()
    os.chdir(ROOT)
    args.out = args.out.resolve()
    if args.command == 'prepare':
        prepare(args)
    else:
        finalize(args)


if __name__ == '__main__':
    main()
