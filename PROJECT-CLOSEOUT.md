# DeskBlocks Project Closeout

## Status

DeskBlocks MVP is complete as of 2026-07-06.

This closeout covers the local private Swift/AppKit prototype. GitHub publishing, remote backup, and personal retrospective are intentionally deferred for the next discussion.

## Final Verification

Completed on 2026-07-06:

| Check | Result |
|---|---|
| `swift build` | Passed |
| `swift run DeskBlocksCoreChecks` | Passed |
| `scripts/build-local-app.sh` | Passed |
| `dist/DeskBlocks.app` exists | Passed |
| `git status --short` before closeout docs | Clean |

## Completed Scope

- User-created desktop blocks with native AppKit windows.
- Whole-tile resizing with fixed tile dimensions.
- Persistent block title, frame, title color, empty-tile visibility, and lock state.
- Folder references stored as app-owned bookmark-backed tile data.
- Folder reference placement, opening, removal, replacement, notes, and drag reordering.
- Optional hidden empty tile placeholders.
- Locked blocks that prevent accidental move and resize while preserving removal and folder-reference actions.
- Native macOS close control that appears only when a selected block is hovered.
- Local unsigned `.app` bundle packaging.

## Known Issues And Limits

- The app is private and unsigned. It is not ready for public distribution.
- No lint command exists.
- No XCTest target exists in the current Command Line Tools setup; core verification uses `DeskBlocksCoreChecks`.
- Manual GUI verification is still required for visual AppKit behavior.
- Persistence is local prototype persistence, not a synced or multi-user data model.
- Blocks do not pass clicks through transparent empty areas to Finder.
- The app does not install login items, request automation permissions, or provide launch-at-login behavior.
- The app does not move, copy, rename, delete, or reorganize Finder folders or desktop icons.

## Local Artifacts

- App bundle: `dist/DeskBlocks.app`
- Product spec: `SPEC.md`
- Main implementation: `Sources/DeskBlocksPrototype/`
- Core checks: `Sources/DeskBlocksCoreChecks/`
- Architecture decisions: `docs/decisions/`

## Deferred Discussion

- GitHub repository setup and push workflow.
- Tagging/release strategy for the MVP.
- Personal project retrospective and lessons learned.
