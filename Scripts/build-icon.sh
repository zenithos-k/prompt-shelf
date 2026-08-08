#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCE_DIR="$PROJECT_DIR/Resources"
SOURCE_ICON="$RESOURCE_DIR/AppIconSource.png"
MASTER_ICON="$RESOURCE_DIR/AppIcon.png"
TEMP_DIR="$(mktemp -d)"
ICONSET_DIR="$TEMP_DIR/AppIcon.iconset"
ICON_HELPER="$TEMP_DIR/prepare-app-icon"
ICNS_HELPER="$TEMP_DIR/build-icns"
MODULE_CACHE="$TEMP_DIR/ModuleCache"
SDK_PATH="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
HOST_ARCH="$(/usr/bin/uname -m)"

trap '/bin/rm -rf "$TEMP_DIR"' EXIT
/bin/mkdir -p "$ICONSET_DIR"

/usr/bin/xcrun swiftc \
    -sdk "$SDK_PATH" \
    -target "$HOST_ARCH-apple-macosx13.0" \
    -module-cache-path "$MODULE_CACHE" \
    -Xfrontend -downgrade-typecheck-interface-error \
    -framework AppKit \
    "$SCRIPT_DIR/prepare-app-icon.swift" \
    -o "$ICON_HELPER"
"$ICON_HELPER" "$SOURCE_ICON" "$MASTER_ICON"

resize_icon() {
    local size="$1"
    local filename="$2"
    /usr/bin/sips -z "$size" "$size" "$MASTER_ICON" --out "$ICONSET_DIR/$filename" >/dev/null
}

resize_icon 16 icon_16x16.png
resize_icon 32 icon_16x16@2x.png
resize_icon 32 icon_32x32.png
resize_icon 64 icon_32x32@2x.png
resize_icon 128 icon_128x128.png
resize_icon 256 icon_128x128@2x.png
resize_icon 256 icon_256x256.png
resize_icon 512 icon_256x256@2x.png
resize_icon 512 icon_512x512.png
resize_icon 1024 icon_512x512@2x.png

if ! /usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$RESOURCE_DIR/AppIcon.icns" 2>/dev/null; then
    /usr/bin/xcrun swiftc \
        -sdk "$SDK_PATH" \
        -target "$HOST_ARCH-apple-macosx13.0" \
        -module-cache-path "$MODULE_CACHE" \
        -Xfrontend -downgrade-typecheck-interface-error \
        "$SCRIPT_DIR/build-icns.swift" \
        -o "$ICNS_HELPER"
    "$ICNS_HELPER" "$ICONSET_DIR" "$RESOURCE_DIR/AppIcon.icns"
fi
echo "$RESOURCE_DIR/AppIcon.icns"
