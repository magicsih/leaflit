#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p build
LEAFLIT_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/Leaflit/Info.plist)
python3 - <<'PYBEGIN'
import datetime, json, pathlib, subprocess
info = {'sourceSHA': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'startedUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'result': 'running', 'checks': []}
pathlib.Path('build/verification.json').write_text(json.dumps(info, indent=2) + '\n')
PYBEGIN
npm ci --ignore-scripts
npm test
npm audit --omit=dev
npm run build
swift test
python3 -m unittest discover -s Tests/PackagingTests
xcodebuild -project Leaflit.xcodeproj -scheme Leaflit -configuration "${1:-Release}" -derivedDataPath "build/DerivedData-$LEAFLIT_VERSION" -destination 'platform=macOS,arch=arm64' ENABLE_TESTABILITY=YES test
python3 - <<'PYINFO'
import datetime, json, pathlib, subprocess
info = {'sourceSHA': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'finishedUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'result': 'passed', 'checks': ['npm test', 'npm audit --omit=dev', 'swift test', 'xcodebuild test', 'packaging tests'], 'environment': 'Apple Silicon local macOS'}
pathlib.Path('build/verification.json').write_text(json.dumps(info, indent=2) + '\n')
PYINFO
