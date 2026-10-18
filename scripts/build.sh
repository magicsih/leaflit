#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p build
npm ci --ignore-scripts
npm run build
xcodebuild -project Leaflit.xcodeproj -scheme Leaflit -configuration "${1:-Release}" -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' clean build
python3 - <<'PYCLEAN'
from pathlib import Path
import shutil
candidate = Path('build/Leaflit-0.1.0')
if candidate.exists():
    shutil.rmtree(candidate)
candidate.mkdir(parents=True)
PYCLEAN
/usr/bin/ditto "build/DerivedData/Build/Products/${1:-Release}/Leaflit.app" build/Leaflit-0.1.0/Leaflit.app
cp scripts/leaflit build/Leaflit-0.1.0/leaflit
python3 - <<'PYINFO'
import hashlib, json, pathlib, subprocess
root = pathlib.Path.cwd()
app = root / 'build/Leaflit-0.1.0/Leaflit.app'
info = {'version': '0.1.0', 'sourceSHA': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'architecture': 'arm64', 'minimumOS': '14.0', 'binarySHA256': hashlib.sha256((app / 'Contents/MacOS/Leaflit').read_bytes()).hexdigest(), 'signing': 'ad-hoc, no Developer ID or notarization'}
(root / 'build/Leaflit-0.1.0/build-info.json').write_text(json.dumps(info, indent=2) + '\n')
PYINFO
