#!/bin/bash
# Screenshots one state of the app on the simulator, through its own -snap
# (the simulator's screenshot fails on this machine).
#   tools/snap.sh <out.png> <launch args...>     e.g. tools/snap.sh shot.png -panel store -AppleLanguages "(en)"
# Build first with:  tools/snap.sh --build
set -e
cd "$(dirname "$0")/.."
SIM="${SIM:-4A148A13-ADC6-47D2-BFB4-4FB2A5C213EF}"
APP=build-sim/Build/Products/Debug-iphonesimulator/cameragr.app
if [ "$1" = "--build" ]; then
  xcodegen generate -q
  mkdir -p build-sim
  xcodebuild -project cameragr.xcodeproj -scheme cameragr -destination "platform=iOS Simulator,id=$SIM" \
    -derivedDataPath build-sim build > build-sim/build.log 2>&1 || { grep error: build-sim/build.log | head; exit 1; }
  xcrun simctl install "$SIM" "$APP"
  echo built; exit 0
fi
OUT="$1"; shift
DOCS="$(xcrun simctl get_app_container "$SIM" com.oneskill.cameragr data)/Documents"
rm -f "$DOCS/snap.png"
xcrun simctl terminate "$SIM" com.oneskill.cameragr 2>/dev/null || true
xcrun simctl launch "$SIM" com.oneskill.cameragr -snap 4 "$@" > /dev/null
for _ in $(seq 1 30); do [ -f "$DOCS/snap.png" ] && break; perl -e 'select(undef,undef,undef,0.5)'; done
[ -f "$DOCS/snap.png" ] || { echo "no snapshot"; exit 1; }
mkdir -p "$(dirname "$OUT")"; cp "$DOCS/snap.png" "$OUT"; echo "$OUT"
