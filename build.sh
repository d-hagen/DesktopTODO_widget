#!/bin/zsh
# Builds ToDo.app with the Swift Package Manager (no Xcode.app needed).
#   ./build.sh            build to build/ToDo.app
#   ./build.sh --install  build, copy to /Applications, relaunch
#   ./build.sh --run      build and launch from build/
set -euo pipefail
cd "$(dirname "$0")"

if ! swift build -c release 2>&1 | grep -v -E '^\[|xcrun: error|^ *$'; then :; fi
BIN=".build/release/ToDo"
[[ -x "$BIN" && -z "$(find Sources -newer "$BIN" -name '*.swift' | head -1)" ]] || { echo "build failed"; exit 1; }

APP="build/ToDo.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ToDo"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" 2>/dev/null
echo "built $APP"

case "${1:-}" in
  --install)
    pkill -x ToDo 2>/dev/null || true
    sleep 0.5
    rm -rf /Applications/ToDo.app
    cp -R "$APP" /Applications/ToDo.app
    open /Applications/ToDo.app
    echo "installed and launched /Applications/ToDo.app"
    ;;
  --run)
    pkill -x ToDo 2>/dev/null || true
    sleep 0.5
    open "$APP"
    ;;
esac
