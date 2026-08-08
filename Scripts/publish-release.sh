#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")"
FILENAME="Prompt-Shelf-$VERSION.dmg"
ARTIFACT="${1:-$PROJECT_DIR/dist/releases/$FILENAME}"
BUCKET_NAME="prompt-shelf-releases"
OBJECT_KEY="releases/$VERSION/$FILENAME"
VERIFY_FILE="$(mktemp "/private/tmp/prompt-shelf-r2-${VERSION}.XXXXXX")"

cleanup() {
    /bin/rm -f "$VERIFY_FILE"
}
trap cleanup EXIT

if ! /usr/bin/which wrangler >/dev/null 2>&1; then
    echo "Wrangler is required to publish a release." >&2
    exit 1
fi

if [[ ! -f "$ARTIFACT" ]]; then
    echo "Release artifact not found: $ARTIFACT" >&2
    echo "Build it first with ./Scripts/build-dmg.sh" >&2
    exit 1
fi

LOCAL_SHA256="$(/usr/bin/shasum -a 256 "$ARTIFACT" | /usr/bin/awk '{ print $1 }')"

cd "$PROJECT_DIR/Website"
wrangler r2 object put "$BUCKET_NAME/$OBJECT_KEY" \
    --remote \
    --file "$ARTIFACT" \
    --content-type "application/x-apple-diskimage" \
    --content-disposition "attachment; filename=\"$FILENAME\"" \
    --cache-control "public, max-age=31536000, immutable"

wrangler r2 object get "$BUCKET_NAME/$OBJECT_KEY" \
    --remote \
    --file "$VERIFY_FILE"

REMOTE_SHA256="$(/usr/bin/shasum -a 256 "$VERIFY_FILE" | /usr/bin/awk '{ print $1 }')"
if [[ "$LOCAL_SHA256" != "$REMOTE_SHA256" ]]; then
    echo "R2 verification failed: local and remote checksums differ." >&2
    exit 1
fi

echo "Uploaded and verified: r2://$BUCKET_NAME/$OBJECT_KEY"
echo "SHA-256: $LOCAL_SHA256"
echo "Public URL: https://prompts.matrdreams.com/downloads/$FILENAME"
