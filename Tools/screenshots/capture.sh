#!/bin/zsh
# App Store raws of the real app on a simulator (the iPhone Duo or a regular iPhone), seeded with exact engine states.
#
#   capture.sh build <udid>                         build the Debug app for that simulator
#   capture.sh state <name> "<keys>"                engine state after the keys (calc CLI names: 1,2,mul,3,eq,…)
#   capture.sh shot <udid> <display|0> <state> <out.png> [defaults-key=value …]
#
# <display> is the simulator screen for `simctl io` (the Duo has a cover and an inner display; 0 = default).
# Extra arguments are written to the app's defaults before launch, e.g. duo.settings.sciPortrait=true.
# History timestamps are fixed (9:41 local) so every capture shows the same times.
set -u
HERE=${0:A:h}
REPO=${HERE:h:h}
OUT=${CAPTURE_DIR:-$HOME/Developer/DuoCalculatorBuilds/liquid-2.0.0-7/raws}
BID=com.liquidcalc.LiquidCalculator
DATE=1791906060
export DEVELOPER_DIR=${DEVELOPER_DIR:-$HOME/Downloads/Xcode-27.1-RC/Xcode.app/Contents/Developer}
mkdir -p "$OUT/states"

ready() {  # wait until the app has drawn (not black/white, stable for one interval); $1 udid $2 display $3 out
  local prev="" i m d
  for i in $(seq 1 40); do
    if [ "$2" = "0" ]; then xcrun simctl io $1 screenshot "$3" >/dev/null 2>&1
    else xcrun simctl io $1 screenshot --display=$2 --mask=ignored "$3" >/dev/null 2>&1; fi
    read m d < <(python3 -I -W ignore - "$3" "$prev" <<'PY'
import sys
from PIL import Image, ImageChops
cur = Image.open(sys.argv[1]).convert("L").resize((200, 200))
m = sum(cur.getdata()) / 40000; d = 999
if sys.argv[2]:
    d = sum(ImageChops.difference(cur, Image.open(sys.argv[2]).convert("L").resize((200, 200))).getdata()) / 40000
print(round(m, 1), round(d, 2))
PY
)
    if python3 -I -c "import sys; sys.exit(0 if (3 < float('$m') < 245 and float('$d') < 1.5) else 1)"; then
      [ -n "$prev" ] && mv "$prev" "$OUT/.settled-prev.png"
      return 0
    fi
    cp "$3" "$3.prev"; prev="$3.prev"; sleep 3
  done
  echo "WARN: not settled $3 (m=$m d=$d)"
}

case "$1" in
build)
  xcodebuild -project "$REPO/App/DuoCalculator.xcodeproj" -scheme DuoCalculator -configuration Debug \
    -destination "id=$2" -derivedDataPath "$OUT/dd" CODE_SIGNING_ALLOWED=NO build > "$OUT/build.log" 2>&1 \
    || { grep -m8 'error:' "$OUT/build.log"; echo BUILD_FAIL; exit 1; }
  APP=$(fd -t d -e app . "$OUT/dd/Build/Products/Debug-iphonesimulator" -d 1 | head -1); echo "$APP" > "$OUT/app.txt"; echo "BUILT $APP"
  ;;
state)
  swift run --package-path "$REPO/Packages/CalcEngine" calc --keys "$3" --date $DATE --dump-state "$OUT/states/$2.json"
  ;;
shot)
  U=$2; D=$3; STATE=$4; SHOT=$5; shift 5
  xcrun simctl terminate $U $BID 2>/dev/null; xcrun simctl install $U "$(cat "$OUT/app.txt")"
  C=$(xcrun simctl get_app_container $U $BID data); P="$C/Library/Preferences/$BID"
  xcrun simctl spawn $U defaults write "$P" duo.settings.appearance -string dark
  xcrun simctl spawn $U defaults write "$P" duo.calculator.state.v1 -data "$(xxd -p "$OUT/states/$STATE.json" | tr -d '\n')"
  for kv in "$@"; do
    case "${kv#*=}" in
      true|false) xcrun simctl spawn $U defaults write "$P" "${kv%%=*}" -bool "${kv#*=}" ;;
      *) xcrun simctl spawn $U defaults write "$P" "${kv%%=*}" -string "${kv#*=}" ;;
    esac
  done
  xcrun simctl launch $U $BID >/dev/null; sleep 4
  ready $U $D "$SHOT"; echo "$SHOT"
  ;;
*)
  sed -n '2,10p' "$0"; exit 2
  ;;
esac
