#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p build
npm ci --ignore-scripts
npm test
npm audit --omit=dev
npm run build
swift test
xcodebuild -project Leaflit.xcodeproj -scheme Leaflit -configuration "${1:-Release}" -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' ENABLE_TESTABILITY=YES test
