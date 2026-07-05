# DeskBlocks

DeskBlocks is a private macOS desktop app for visual desktop organization. It creates user-defined desktop blocks with fixed-size folder tiles so folders and labels stay readable while block frames resize in whole-tile steps.

The current project state is an MVP-complete Swift/AppKit prototype. It is intended for private local use and proves the desktop-block interaction model rather than acting as a general dashboard or window manager.

## Requirements

- macOS 15 or newer
- Xcode Command Line Tools with Swift 6 support

## Quick Start

Build and run the prototype from the repository root:

```bash
swift build
swift run DeskBlocksPrototype
```

Build the local unsigned app bundle:

```bash
scripts/build-local-app.sh
```

The app bundle is written to:

```text
dist/DeskBlocks.app
```

## Commands

| Command | Description |
|---|---|
| `swift build` | Build the Swift package. |
| `swift run DeskBlocksPrototype` | Run the AppKit prototype. |
| `swift run DeskBlocksCoreChecks` | Run the current core grid, snapping, state, and persistence checks. |
| `scripts/build-local-app.sh` | Build the private local unsigned `.app` bundle. |

There is no lint command yet. The current Command Line Tools setup does not provide an importable XCTest module for SwiftPM tests, so the project uses `swift run DeskBlocksCoreChecks` for executable checks.

## Product Scope

DeskBlocks supports:

- Creating titled desktop blocks.
- Moving and resizing blocks while keeping tile dimensions fixed.
- Persisting block title, frame, title color, empty-tile visibility, lock state, and folder references.
- Adding Finder folder references to tiles without moving, copying, renaming, or deleting underlying Finder folders.
- Opening, replacing, removing, and reordering folder references.
- Adding app-owned notes to folder references.
- Hiding empty tile placeholders.
- Locking blocks against accidental move and resize while still allowing block removal and folder-reference actions.

DeskBlocks intentionally does not:

- Manage Finder files or folders as owned data.
- Move real Finder desktop icons.
- Act as a dashboard or window manager.
- Provide app signing, distribution, login items, or external services.

## Architecture

- `Sources/DeskBlocksCore/` contains pure Swift grid, snapping, state, and persistence-safe model logic.
- `Sources/DeskBlocksCoreChecks/` contains executable checks for current invariants.
- `Sources/DeskBlocksPrototype/` contains the Swift/AppKit prototype.
- `packaging/` and `scripts/build-local-app.sh` build the local unsigned app bundle.
- `docs/decisions/` records accepted architecture and persistence decisions.

The product and technical source of truth is `SPEC.md`.

## Status

MVP complete as of 2026-07-06. See `PROJECT-CLOSEOUT.md` for final verification notes and known issues.
