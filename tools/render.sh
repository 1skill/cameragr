#!/bin/bash
# Renders one screen at the Duo's real size through the app's -render
# (inner: the bag 951x669 pt, finder: a half-fold half 669x475 pt, @3x).
#   tools/render.sh <inner|finder> <out.png> <launch args...>
# Waits for a render newer than the launch; the old one is left in place.
set -e
cd "$(dirname "$0")/.."
SIM="${SIM:-4A148A13-ADC6-47D2-BFB4-4FB2A5C213EF}"
WHAT="$1"; OUT="$2"; shift 2
DOCS="$(xcrun simctl get_app_container "$SIM" com.oneskill.cameragr data)/Documents"
STAMP="$(mktemp)"
xcrun simctl terminate "$SIM" com.oneskill.cameragr 2>/dev/null || true
xcrun simctl launch "$SIM" com.oneskill.cameragr -render "$WHAT" "$@" > /dev/null
for _ in $(seq 1 60); do
  [ "$DOCS/render.png" -nt "$STAMP" ] && break
  perl -e 'select(undef,undef,undef,0.5)'
done
[ "$DOCS/render.png" -nt "$STAMP" ] || { echo "no render"; exit 1; }
perl -e 'select(undef,undef,undef,0.5)'   # let the write finish
mkdir -p "$(dirname "$OUT")"; cp "$DOCS/render.png" "$OUT"; echo "$OUT"
