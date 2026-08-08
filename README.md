# Prompt Shelf

A native macOS menu bar prompt manager built with Swift and SwiftUI. Prompt Shelf keeps reusable prompts one click away, supports drag-and-drop ordering, and turns `{{variables}}` into a fill-in form automatically.

[Website](https://prompts.matrdreams.com) · [Download Prompt Shelf 1.4.3](https://prompts.matrdreams.com/downloads/Prompt-Shelf-1.4.3.dmg?v=07f27105-r2)

> Prompt Shelf is source-available and currently distributed as a free, non-notarized build. See [Distribution status](#distribution-status) before sharing it with other users.

## Why Prompt Shelf

Prompt libraries are often buried in notes, text expanders, or previous chat sessions. Prompt Shelf is intentionally narrower: it provides fast access from the macOS menu bar without accounts, sync services, browser runtimes, or a persistent Dock icon.

Core advantages:

- **Native interaction:** `MenuBarExtra`, SwiftUI controls, system materials, keyboard shortcuts, and macOS appearance support.
- **Deterministic ordering:** drag a row handle to place a prompt; array order is persisted and restored exactly.
- **Zero-configuration templates:** any unique token matching `{{variable_name}}` becomes a field before copy.
- **Local-first data:** prompts are stored in a readable, versioned JSON document on the current Mac.
- **Small runtime surface:** no Electron, embedded web view, third-party SDK, analytics, or network request.

## Features

- Create, edit, search, copy, and delete prompts
- Gesture-based ordering across the complete prompt list
- Automatic `{{variable}}` detection, live rendering, and validation
- System, light, and dark appearance modes
- Optional close-after-copy behavior
- Optional launch at login
- JSON import and export with order preservation
- Atomic background persistence with coalesced writes
- Confirmation before destructive actions
- Menu bar presentation without a Dock icon

## Architecture

```text
Sources/PromptShelf/
├── Models/
│   ├── PromptSnippet.swift         Prompt identity and content
│   └── PromptTemplate.swift        Variable parsing and rendering
├── Persistence/
│   ├── PromptRepository.swift      Versioned JSON encoding and atomic writes
│   └── PromptPersistenceCoordinator.swift
├── Services/
│   ├── AppPreferences.swift        Appearance and behavior preferences
│   ├── ClipboardService.swift
│   └── LaunchAtLoginController.swift
├── Store/
│   └── PromptStore.swift           Application state and ordering operations
├── Views/
│   ├── LibraryView.swift
│   ├── PromptRow.swift
│   ├── PromptEditorView.swift
│   ├── VariableFillView.swift
│   └── SettingsView.swift
└── PromptShelfApp.swift            Menu bar scene and lifecycle
```

The UI observes a single `PromptStore`. Mutations update in-memory ordering immediately, while `PromptPersistenceCoordinator` coalesces consecutive writes on a serial utility queue. A final synchronous flush runs before termination or menu presentation teardown.

## Template syntax

Variables use double braces:

```text
Explain {{file}}, focusing on {{topic}}.
Compare {{topic}} with the previous implementation.
```

The parser trims surrounding whitespace, preserves first-seen order, and deduplicates repeated variable names. In this example, the copy form contains two fields: `file` and `topic`.

Prompt rendering is deterministic: values replace every matching occurrence, while missing values remain visible as their original tokens.

## Persistence format

The default database location is:

```text
~/Library/Application Support/PromptShelf/prompts.json
```

The JSON root includes an explicit schema version. Prompt array order is the display order, so no separate rank index needs to be maintained. Writes use an atomic replacement strategy to avoid partially written documents.

Prompt Shelf does not transmit this file or its contents. Import and export are explicit user actions through native file panels.

## Requirements

### Run

- macOS 13.0 or later

### Build

- Swift 6
- macOS SDK and Command Line Tools capable of building SwiftUI applications
- Xcode 16 or later recommended

When built with the macOS 26 SDK, Prompt Shelf uses Liquid Glass where available. Compile-time and runtime availability checks preserve compatibility with older supported systems.

## Development

Build and run the Swift package:

```bash
swift build
swift run PromptShelf
```

Run the test suite:

```bash
swift test
```

Tests cover variable parsing and rendering, repository compatibility, persistence behavior, and store ordering.

Build a standard application bundle:

```bash
./Scripts/build-app.sh
open "dist/Prompt Shelf.app"
```

Create the styled release DMG:

```bash
./Scripts/build-dmg.sh
```

## Performance and compatibility

- `LazyVStack` prevents the library from eagerly instantiating every prompt row.
- Variable extraction reuses a single compiled regular expression.
- Persistence runs away from the main actor on a serial utility queue.
- Consecutive reorder writes are coalesced; the final state is flushed explicitly.
- The application has no runtime package dependencies or network client.

## Privacy and security

Prompt Shelf requires no account and includes no telemetry or analytics. Application data stays in the local JSON document described above.

Before publishing a release, verify at minimum:

```bash
codesign --verify --deep --strict --verbose=2 "dist/Prompt Shelf.app"
hdiutil verify "dist/releases/Prompt-Shelf-1.4.3.dmg"
shasum -a 256 "dist/releases/Prompt-Shelf-1.4.3.dmg"
```

## Distribution status

The repository does not currently have access to an Apple Developer ID signing identity. Local release builds are therefore ad-hoc signed and cannot be notarized. macOS Gatekeeper may block the first launch after download; users must explicitly approve it in **System Settings → Privacy & Security → Open Anyway**.

For frictionless public distribution, sign the app with a `Developer ID Application` certificate, submit it with `notarytool`, staple the ticket, and rebuild the DMG. The release script is structured so proper signing can replace ad-hoc signing once a certificate is available.

## Website

`Website/site` contains the dependency-free landing page. Cloudflare Workers Static Assets serves the site from `prompts.matrdreams.com`, while versioned DMGs live in the private `prompt-shelf-releases` R2 bucket. The Worker streams downloads through the existing `/downloads/Prompt-Shelf-<version>.dmg` URLs and supports HTTP range requests.

DMGs are intentionally excluded from Git history. Build and upload the version in `Info.plist` with:

```bash
./Scripts/build-dmg.sh
./Scripts/publish-release.sh
```

After updating the landing-page download links for a new release, deploy the Worker and static assets separately:

```bash
cd Website && wrangler deploy
```

The Worker publishes the SHA-256 checksum as response metadata for known releases. Add each new checksum to `Website/src/index.js` before deploying the new download link.
