#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This build runs on a GitHub macOS runner or a Mac with Xcode." >&2
  exit 1
fi
mkdir -p build/ipa
xcodebuild -version
xcodebuild -project UntitledCompressor.xcodeproj \
  -scheme UntitledCompressor -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  build 2>&1 | tee build/device-build.log
python3 tools/package_ipa.py \
  'build/DerivedData/Build/Products/Release-iphoneos/Untitled Compressor.app' \
  build/ipa/Untitled-Compressor-unsigned.ipa
