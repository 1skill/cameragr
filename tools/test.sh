#!/bin/bash
# Runs the unit tests on the simulator and prints each result.
# Tests run one at a time: the purchase tests share the app's one store.
# Exit status: 0 only if the project generated and the run succeeded.
#   SIM=<simulator id> tools/test.sh   (default: the iPhone Duo simulator)
set -o pipefail
cd "$(dirname "$0")/.."
SIM="${SIM:-4A148A13-ADC6-47D2-BFB4-4FB2A5C213EF}"
xcrun simctl list devices | grep -q "$SIM" || { echo "simulator $SIM not found (set SIM=<id>)"; exit 1; }
xcodegen generate -q || { echo "xcodegen failed"; exit 1; }
mkdir -p build-sim
xcodebuild test -project cameragr.xcodeproj -scheme cameragr \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath build-sim -parallel-testing-enabled NO > build-sim/test.log 2>&1
status=$?
grep -E "✔ Test|✘|Test run with|error:|TEST (SUCCEEDED|FAILED)" build-sim/test.log | sed 's/^.*\] //' | tail -60
exit $status
