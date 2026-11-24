#!/bin/sh
set -eu

base=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
derived="$base/.attune-build/ios"
device="${1:-}"
if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [simulator UDID]\n' "$0" >&2
  exit 2
fi

if [ -z "$device" ]; then
  available=$(xcrun simctl list devices available --json)
  device=$(printf '%s' "$available" | /usr/bin/python3 -c '
import json, re, sys

matches = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    version = re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime)
    if not version:
        continue
    release = tuple(map(int, version[1].split("-")))
    if release < (17,):
        continue
    for row in devices:
        if row.get("isAvailable") and row["name"].startswith("iPhone"):
            matches.append((row["state"] == "Booted", release, row.get("lastBootedAt", ""), row["udid"]))
if matches:
    print(max(matches)[-1])
')
fi

if [ -z "$device" ]; then
  printf '%s\n' 'No available iPhone simulator with iOS 17 or later. In Xcode → Settings → Components, install an iOS runtime, then add an iPhone in Window → Devices and Simulators if needed.' >&2
  exit 1
fi

xcodebuild -quiet -project "$base/Attune.xcodeproj" -scheme Attune -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO build
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$derived/Build/Products/Debug-iphonesimulator/Attune.app"
xcrun simctl launch --terminate-running-process "$device" edu.umich.attune.prototype
open -a "$(xcode-select -p)/Applications/Simulator.app"
