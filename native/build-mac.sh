#!/bin/sh
set -eu
base=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
output="$base/.attune-build"
xcodebuild -project "$base/Attune.xcodeproj" -scheme Attune -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$output" CODE_SIGNING_ALLOWED=NO build
printf '\nApplication: %s\n' "$output/Build/Products/Debug/Attune.app"
