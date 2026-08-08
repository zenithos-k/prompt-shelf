#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="$PROJECT_DIR/.build-universal"
PRODUCT_NAME="Prompt Shelf"
APP_DIR="$PROJECT_DIR/dist/$PRODUCT_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
SDK_PATH="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"

SOURCES=()
while IFS= read -r -d '' source; do
    SOURCES+=("$source")
done < <(/usr/bin/find "$PROJECT_DIR/Sources" -name '*.swift' -type f -print0)

build_architecture() {
    local architecture="$1"
    local triple="${architecture}-apple-macosx13.0"
    local scratch="$BUILD_ROOT/$architecture"
    local binary="$scratch/PromptShelf"

    /bin/rm -rf "$scratch"
    /bin/mkdir -p "$scratch/ModuleCache"
    /usr/bin/xcrun swiftc \
        -O \
        -whole-module-optimization \
        -parse-as-library \
        -swift-version 6 \
        -module-name PromptShelf \
        -target "$triple" \
        -sdk "$SDK_PATH" \
        -module-cache-path "$scratch/ModuleCache" \
        -Xfrontend -downgrade-typecheck-interface-error \
        "${SOURCES[@]}" \
        -o "$binary"

    echo "$binary"
}

"$SCRIPT_DIR/build-icon.sh" >/dev/null
ARM64_BIN="$(build_architecture arm64 | tail -n 1)"
X86_64_BIN="$(build_architecture x86_64 | tail -n 1)"

/bin/rm -rf "$APP_DIR"
/bin/mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
/usr/bin/lipo -create \
    "$ARM64_BIN" \
    "$X86_64_BIN" \
    -output "$CONTENTS_DIR/MacOS/PromptShelf"
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
