#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p build
npm ci --ignore-scripts
npm run build
xcodebuild -project Leaflit.xcodeproj -scheme Leaflit -configuration "${1:-Release}" -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build
mkdir -p build/Leaflit-0.1.0
/usr/bin/ditto "build/DerivedData/Build/Products/${1:-Release}/Leaflit.app" build/Leaflit-0.1.0/Leaflit.app
cp scripts/leaflit build/Leaflit-0.1.0/leaflit
