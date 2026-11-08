#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Run this script on your friend's Mac, with Xcode selected." >&2
  exit 1
fi
xcodebuild -version
xcodebuild -resolvePackageDependencies -project UntitledCompressor.xcodeproj -scheme UntitledCompressor
MODE="${1:-build}"
DESTINATION="${IOS_DESTINATION:-generic/platform=iOS Simulator}"
case "$MODE" in
  build)
    xcodebuild -project UntitledCompressor.xcodeproj -scheme UntitledCompressor \
      -configuration Debug -destination "$DESTINATION" -derivedDataPath build/DerivedData \
      CODE_SIGNING_ALLOWED=NO build
    ;;
  test)
    if [[ -z "${IOS_DESTINATION:-}" ]]; then
      echo 'Set IOS_DESTINATION to an available iPhone simulator, for example:' >&2
      echo 'IOS_DESTINATION="platform=iOS Simulator,name=iPhone 16" bash build-mac.sh test' >&2
      echo 'Available destinations:' >&2
      xcodebuild -project UntitledCompressor.xcodeproj -scheme UntitledCompressor -showdestinations
      exit 1
    fi
    xcodebuild -project UntitledCompressor.xcodeproj -scheme UntitledCompressor \
      -configuration Debug -destination "$IOS_DESTINATION" -derivedDataPath build/DerivedData \
      -resultBundlePath "build/Tests-$(date +%Y%m%d-%H%M%S).xcresult" CODE_SIGNING_ALLOWED=NO test
    ;;
  *) echo "Usage: bash build-mac.sh [build|test]" >&2; exit 1 ;;
esac
