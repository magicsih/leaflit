#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p build
LEAFLIT_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/Leaflit/Info.plist)
LEAFLIT_CANDIDATE_DIR="build/Leaflit-$LEAFLIT_VERSION"
export LEAFLIT_CANDIDATE_DIR
npm ci --ignore-scripts
npm run build
xcodebuild -project Leaflit.xcodeproj -scheme Leaflit -configuration "${1:-Release}" -derivedDataPath "build/DerivedData-$LEAFLIT_VERSION" -destination 'platform=macOS,arch=arm64' clean build
python3 - <<'PYCLEAN'
from pathlib import Path
import shutil
import os
candidate = Path(os.environ['LEAFLIT_CANDIDATE_DIR'])
if candidate.exists():
    shutil.rmtree(candidate)
candidate.mkdir(parents=True)
PYCLEAN
/usr/bin/ditto "build/DerivedData-$LEAFLIT_VERSION/Build/Products/${1:-Release}/Leaflit.app" "$LEAFLIT_CANDIDATE_DIR/Leaflit.app"
cp scripts/leaflit "$LEAFLIT_CANDIDATE_DIR/leaflit"
python3 - <<'PYINFO'
import hashlib, json, pathlib, subprocess, os, plistlib
root = pathlib.Path.cwd()
candidate = root / os.environ['LEAFLIT_CANDIDATE_DIR']
app = candidate / 'Leaflit.app'
bundle = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
expected = plistlib.loads((root / 'Sources/Leaflit/Info.plist').read_bytes())
assert bundle['CFBundleShortVersionString'] == expected['CFBundleShortVersionString'], 'The copied app version does not match the source'
info = {'version': bundle['CFBundleShortVersionString'], 'sourceSHA': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'architecture': 'arm64', 'minimumOS': bundle['LSMinimumSystemVersion'], 'binarySHA256': hashlib.sha256((app / 'Contents/MacOS/Leaflit').read_bytes()).hexdigest(), 'signing': 'ad-hoc, no Developer ID or notarization'}
(candidate / 'build-info.json').write_text(json.dumps(info, indent=2) + '\n')
PYINFO
