#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="$(uname -m)"
case "$ARCH" in
  arm64) HOST_ARCH="arm64" ;;
  x86_64) HOST_ARCH="x64" ;;
  *) HOST_ARCH="$ARCH" ;;
esac

RELEASE_APP="$REPO_ROOT/flutter_app/build/macos/Build/Products/Release/Panorama.app"
DEBUG_APP="$REPO_ROOT/flutter_app/build/macos/Build/Products/Debug/Panorama.app"
if [[ -d "$RELEASE_APP" ]]; then
  BUILT_APP="$RELEASE_APP"
else
  BUILT_APP="$DEBUG_APP"
fi

LAUNCHER_APP="/Applications/Panorama.app"
STAGING="$REPO_ROOT/release/Panorama-launcher.app"
ICON_SOURCE="$REPO_ROOT/build/icon.png"
REPO_QUOTED="$(printf '%q' "$REPO_ROOT")"

write_file() {
  local file_path="$1"
  local mode="${2:-0644}"
  mkdir -p "$(dirname "$file_path")"
  cat >"$file_path"
  chmod "$mode" "$file_path"
}

build_icon() {
  local resources_dir="$1"
  if [[ ! -f "$ICON_SOURCE" ]]; then
    return 0
  fi

  local iconset="$REPO_ROOT/release/Panorama-launcher.iconset"
  rm -rf "$iconset"
  mkdir -p "$iconset"

  local sizes=(
    "16:icon_16x16.png"
    "32:ivan.p@example.net"
    "32:icon_32x32.png"
    "64:ivan.p@example.net"
    "128:icon_128x128.png"
    "256:wendy.h@example.net"
    "256:icon_256x256.png"
    "512:wendy.h@example.net"
    "512:icon_512x512.png"
    "1024:walt.e@example.net"
  )

  for entry in "${sizes[@]}"; do
    local size="${entry%%:*}"
    local name="${entry#*:}"
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$iconset/$name" >/dev/null
  done

  iconutil -c icns "$iconset" -o "$resources_dir/AppIcon.icns" >/dev/null
  rm -rf "$iconset"
}

rm -rf "$STAGING"
mkdir -p "$STAGING/Contents/MacOS" "$STAGING/Contents/Resources"

write_file "$STAGING/Contents/MacOS/Panorama" 0755 <<EOF
#!/bin/bash
set -euo pipefail

REPO=$REPO_QUOTED
RELEASE_APP="\$REPO/flutter_app/build/macos/Build/Products/Release/Panorama.app"
DEBUG_APP="\$REPO/flutter_app/build/macos/Build/Products/Debug/Panorama.app"

if [[ -d "\$RELEASE_APP" ]]; then
  APP="\$RELEASE_APP"
elif [[ -d "\$DEBUG_APP" ]]; then
  APP="\$DEBUG_APP"
else
  osascript <<OSASCRIPT
display dialog "No Panorama Flutter build found.

Expected:
\$RELEASE_APP

Run: (cd flutter_app && flutter build macos), then ./scripts/install-mac.sh" buttons {"OK"} default button 1 with title "Panorama" with icon caution
OSASCRIPT
  exit 1
fi

# Launch the binary directly — Flutter debug bundles can fail with open(1).
exec "\$APP/Contents/MacOS/Panorama"
EOF

write_file "$STAGING/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Panorama</string>
  <key>CFBundleExecutable</key>
  <string>Panorama</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.panorama.fileexplorer.launcher</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Panorama</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleURLTypes</key>
  <array/>
</dict>
</plist>
EOF

build_icon "$STAGING/Contents/Resources"

osascript -e 'tell application "Panorama" to quit' >/dev/null 2>&1 || true

rm -rf "$LAUNCHER_APP"
cp -R "$STAGING" "$LAUNCHER_APP"

codesign --force --deep --sign - "$LAUNCHER_APP" >/dev/null
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$LAUNCHER_APP"

echo "Installed Spotlight launcher → $LAUNCHER_APP"
echo "It opens: $BUILT_APP"
if [[ -d "$BUILT_APP" ]]; then
  echo "Build is present — Cmd+Space “Panorama” will launch it."
else
  echo "No build yet — run: (cd flutter_app && flutter build macos), then re-run this script."
fi
echo "Host: $(hostname) ($HOST_ARCH)"
