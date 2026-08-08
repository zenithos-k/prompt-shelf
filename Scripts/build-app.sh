#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PRODUCT_NAME="Prompt Shelf"
APP_DIR="$PROJECT_DIR/dist/$PRODUCT_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
BUILD_ROOT="$PROJECT_DIR/.build-direct"
SDK_PATH="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
ARCHITECTURE="$(/usr/bin/uname -m)"
BIN_PATH="$BUILD_ROOT/$ARCHITECTURE/PromptShelf"
MODULE_CACHE="$BUILD_ROOT/$ARCHITECTURE/ModuleCache"

SOURCES=()
while IFS= read -r -d '' source; do
    SOURCES+=("$source")
done < <(/usr/bin/find "$PROJECT_DIR/Sources" -name '*.swift' -type f -print0)

"$SCRIPT_DIR/build-icon.sh" >/dev/null
/bin/rm -rf "$BUILD_ROOT/$ARCHITECTURE"
/bin/mkdir -p "$MODULE_CACHE"
/usr/bin/xcrun swiftc \
    -O \
    -whole-module-optimization \
    -parse-as-library \
    -swift-version 6 \
    -module-name PromptShelf \
    -target "$ARCHITECTURE-apple-macosx13.0" \
    -sdk "$SDK_PATH" \
    -module-cache-path "$MODULE_CACHE" \
    -Xfrontend -downgrade-typecheck-interface-error \
    "${SOURCES[@]}" \
    -o "$BIN_PATH"

/bin/rm -rf "$APP_DIR"
/bin/mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
/bin/cp "$BIN_PATH" "$CONTENTS_DIR/MacOS/PromptShelf"
/bin/cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
/bin/cp "$PROJECT_DIR/Resources/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"
/bin/cp "$PROJECT_DIR/Resources/AppIcon.png" "$CONTENTS_DIR/Resources/AppIcon.png"
/bin/chmod 755 "$CONTENTS_DIR/MacOS/PromptShelf"
/usr/bin/plutil -lint "$CONTENTS_DIR/Info.plist"
sign_bundle() {
    local attempt
    for attempt in 1 2 3; do
        /usr/bin/xattr -cr "$APP_DIR"
        /usr/bin/xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
        /usr/bin/xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true
        if /usr/bin/codesign --force --sign - --timestamp=none "$APP_DIR"; then
            /usr/bin/xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
            return 0
        fi
    done
    return 1
}

sign_bundle

echo "$APP_DIR"
