#!/bin/zsh
# Build Subs.app and install it to /Applications, signed with the stable
# Apple Development identity from project.yml (so the Keychain grant
# survives rebuilds). Regenerates the Xcode project and the icon every time.
#
#   ./scripts/build-app.sh            # Release → /Applications/Subs.app
#   ./scripts/build-app.sh --debug
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
housekit="${HOUSEKIT_PATH:-$here/../housekit}"
config=Release
[[ "${1:-}" == "--debug" ]] && config=Debug

swift build -c release --package-path "$housekit" >/dev/null
icon="$(swift build -c release --package-path "$housekit" --show-bin-path)/housekit-icon"
"$icon" subs "$here/Subs/Resources/AppIcon.icns" >/dev/null
# An LSUIElement app can get the generic icon from applicationIconImage, so
# About reads this asset instead.
"$icon" subs "$here/Subs/Resources/Assets.xcassets/AboutAppIcon.imageset/AboutAppIcon.png" 512 >/dev/null

cd "$here"
xcodegen generate --quiet
build="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
xcodebuild -project Subs.xcodeproj -scheme Subs -configuration "$config" \
  -derivedDataPath build/DerivedData CURRENT_PROJECT_VERSION="$build" \
  CODE_SIGNING_ALLOWED=NO -quiet build
app="build/DerivedData/Build/Products/$config/Subs.app"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$app/Contents/Info.plist"
# Xcode's Debug product is an executable shim that loads Subs.debug.dylib at
# launch. Sign nested code first, otherwise dyld rejects the debug dylib.
setopt null_glob
for nested in "$app/Contents/MacOS"/*.dylib "$app/Contents/Frameworks"/*.dylib; do
  codesign --force --sign "Apple Development" --options runtime "$nested"
done
codesign --force --sign "Apple Development" --entitlements Subs/Resources/Subs.entitlements --options runtime "$app"

target=/Applications/Subs.app
if pgrep -xq Subs; then osascript -e 'tell application "Subs" to quit' >/dev/null 2>&1 || true; sleep 0.5; fi
rm -rf "$target"
/usr/bin/ditto "$app" "$target"
codesign --verify --strict "$target"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$target/Contents/Info.plist")"
printf '%s (version %s, build %s)\n' "$target" "$version" "$build"
