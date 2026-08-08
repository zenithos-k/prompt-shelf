#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PRODUCT_NAME="Prompt Shelf"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")"
APP_DIR="$PROJECT_DIR/dist/$PRODUCT_NAME.app"
OUTPUT_DIR="$PROJECT_DIR/dist/releases"
OUTPUT_DMG="$OUTPUT_DIR/Prompt-Shelf-$VERSION.dmg"
BACKGROUND_SOURCE="$PROJECT_DIR/Scripts/create-dmg-background.swift"
BACKGROUND_PNG="$PROJECT_DIR/.build-dmg/background.png"
SIGN_IDENTITY="${PROMPT_SHELF_SIGN_IDENTITY:--}"
NOTARY_PROFILE="${PROMPT_SHELF_NOTARY_PROFILE:-}"

WORK_DIR="$(mktemp -d /private/tmp/prompt-shelf-release.XXXXXX)"
STAGING_DIR="$WORK_DIR/staging"
MOUNT_DIR=""
RW_DMG="$WORK_DIR/Prompt-Shelf-rw.dmg"

cleanup() {
    if [[ -n "$MOUNT_DIR" ]] && /usr/bin/hdiutil info | /usr/bin/grep -Fq "$MOUNT_DIR"; then
        /usr/bin/hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
    fi
    /bin/rm -rf "$WORK_DIR"
}
trap cleanup EXIT

"$SCRIPT_DIR/build-universal-app.sh" >/dev/null

/usr/bin/xattr -cr "$APP_DIR"
/usr/bin/xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
/usr/bin/xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    /usr/bin/codesign --force --deep --sign - --timestamp=none "$APP_DIR"
    echo "Warning: no Developer ID identity configured; using an ad-hoc signature." >&2
else
    /usr/bin/codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --sign "$SIGN_IDENTITY" \
        "$APP_DIR"
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DIR"

/bin/mkdir -p "$STAGING_DIR/.background" "$OUTPUT_DIR" "$(dirname "$BACKGROUND_PNG")"
/usr/bin/ditto "$APP_DIR" "$STAGING_DIR/$PRODUCT_NAME.app"
/bin/ln -s /Applications "$STAGING_DIR/Applications"
/bin/cp "$PROJECT_DIR/Resources/AppIcon.icns" "$STAGING_DIR/.VolumeIcon.icns"

SDK_PATH="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
/usr/bin/xcrun swiftc \
    -sdk "$SDK_PATH" \
    -module-cache-path "$PROJECT_DIR/.build-dmg/ModuleCache" \
    -Xfrontend -downgrade-typecheck-interface-error \
    "$BACKGROUND_SOURCE" \
    -o "$PROJECT_DIR/.build-dmg/create-dmg-background"
"$PROJECT_DIR/.build-dmg/create-dmg-background" "$BACKGROUND_PNG"
/bin/cp "$BACKGROUND_PNG" "$STAGING_DIR/.background/background.png"

/usr/bin/hdiutil create \
    -volname "$PRODUCT_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    "$RW_DMG" >/dev/null

ATTACH_OUTPUT="$(/usr/bin/hdiutil attach \
    -readwrite \
    -noverify \
    -noautoopen \
    "$RW_DMG")"
MOUNT_DIR="$(printf '%s\n' "$ATTACH_OUTPUT" | /usr/bin/awk -F '\t' 'END { print $NF }')"
VOLUME_NAME="$(/usr/bin/basename "$MOUNT_DIR")"

if [[ ! -d "$MOUNT_DIR" ]]; then
    echo "Unable to locate the mounted DMG volume." >&2
    exit 1
fi

/usr/bin/SetFile -a C "$MOUNT_DIR"
/usr/bin/SetFile -a V "$MOUNT_DIR/.background"
/usr/bin/SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns"

/usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        set the bounds of container window to {180, 140, 840, 595}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 104
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.png"
        set position of item "$PRODUCT_NAME.app" of container window to {170, 220}
        set position of item "Applications" of container window to {490, 220}
        update without registering applications
        delay 2
        close container window
    end tell
end tell
APPLESCRIPT

/bin/sync
/usr/bin/hdiutil detach "$MOUNT_DIR" >/dev/null
MOUNT_DIR=""
/bin/rm -f "$OUTPUT_DMG"
/usr/bin/hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_DMG" >/dev/null

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    /usr/bin/codesign --force --timestamp --sign "$SIGN_IDENTITY" "$OUTPUT_DMG"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        echo "A Developer ID identity is required before notarization." >&2
        exit 1
    fi
    /usr/bin/xcrun notarytool submit "$OUTPUT_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    /usr/bin/xcrun stapler staple "$OUTPUT_DMG"
    /usr/bin/xcrun stapler validate "$OUTPUT_DMG"
fi

/usr/bin/hdiutil verify "$OUTPUT_DMG" >/dev/null
echo "$OUTPUT_DMG"
/usr/bin/stat -f '%z bytes' "$OUTPUT_DMG"
/usr/bin/shasum -a 256 "$OUTPUT_DMG"
