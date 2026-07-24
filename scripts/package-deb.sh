#!/usr/bin/env bash
# Package the Flutter Linux release bundle into a .deb.
# Usage: ./scripts/package-deb.sh <version> [bundle_dir] [output_dir]
set -euo pipefail

VERSION="${1:?version required (e.g. 1.0.6)}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_DIR="${2:-$REPO_ROOT/flutter_app/build/linux/x64/release/bundle}"
OUTPUT_DIR="${3:-$REPO_ROOT/release}"
ARCH="amd64"
PKG_NAME="panorama"
DEB_ROOT="$(mktemp -d)"
STAGE="$DEB_ROOT/${PKG_NAME}_${VERSION}_${ARCH}"

cleanup() { rm -rf "$DEB_ROOT"; }
trap cleanup EXIT

if [[ ! -x "$BUNDLE_DIR/panorama" ]]; then
  echo "Missing Linux release bundle at: $BUNDLE_DIR" >&2
  echo "Build first: (cd flutter_app && flutter build linux --release)" >&2
  exit 1
fi

mkdir -p \
  "$STAGE/DEBIAN" \
  "$STAGE/usr/bin" \
  "$STAGE/usr/lib/panorama" \
  "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/icons/hicolor/256x256/apps" \
  "$STAGE/usr/share/doc/panorama"

cp -a "$BUNDLE_DIR"/. "$STAGE/usr/lib/panorama/"
chmod 755 "$STAGE/usr/lib/panorama/panorama"

# Launcher so PATH finds the app without breaking the bundle's relative lib/data layout.
cat >"$STAGE/usr/bin/panorama" <<'EOF'
#!/bin/sh
exec /usr/lib/panorama/panorama "$@"
EOF
chmod 755 "$STAGE/usr/bin/panorama"

cp "$REPO_ROOT/flutter_app/linux/packaging/panorama.desktop" \
  "$STAGE/usr/share/applications/panorama.desktop"

ICON_SRC="$REPO_ROOT/flutter_app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$STAGE/usr/share/icons/hicolor/256x256/apps/panorama.png"
fi

cat >"$STAGE/usr/share/doc/panorama/copyright" <<'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: Panorama
Source: https://github.com/merklegroot/panorama

Files: *
Copyright: Panorama contributors
License: proprietary
EOF

SIZE_KB="$(du -sk "$STAGE" | awk '{print $1}')"

cat >"$STAGE/DEBIAN/control" <<EOF
Package: panorama
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Installed-Size: ${SIZE_KB}
Maintainer: Panorama contributors <noreply@users.noreply.github.com>
Homepage: https://github.com/merklegroot/panorama
Depends: libgtk-3-0 | libgtk-3-0t64, libblkid1 | libblkid1t64, liblzma5, libglib2.0-0 | libglib2.0-0t64
Description: Windows Explorer-inspired desktop file manager
 Panorama is a dual-pane file explorer for the desktop with Quick Access
 locations, trash support, an in-app terminal, and drag-and-drop import.
EOF

cat >"$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q /usr/share/icons/hicolor || true
fi
exit 0
EOF
chmod 755 "$STAGE/DEBIAN/postinst"

mkdir -p "$OUTPUT_DIR"
OUT_DEB="$OUTPUT_DIR/Panorama-${VERSION}-linux-amd64.deb"
dpkg-deb --build --root-owner-group "$STAGE" "$OUT_DEB"
echo "Wrote $OUT_DEB"
