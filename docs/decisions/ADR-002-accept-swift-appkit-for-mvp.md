# ADR-002: Accept Swift/AppKit For The MVP App Stack

## Status

Accepted

## Date

2026-07-02

## Context

ADR-001 required DeskBlocks to prove macOS desktop behavior before choosing the production app stack. The first feasibility candidate was Swift/AppKit because DeskBlocks' main risk is native desktop-window behavior, not general UI rendering.

The Swift/AppKit feasibility prototype now demonstrates the required MVP direction:

- One desktop block launches through Swift Package Manager.
- The block uses fixed-size tile metrics with whole-tile resize snapping.
- The block can be dragged and resized by pointer interaction.
- Title, position, size, and future tile-reference state persist through JSON.
- The current overlay candidate uses `CGWindowLevelForKey(.desktopIconWindow) + 1`.
- Candidate `desktopIconWindow - 1` failed because the block was visible but not selectable, draggable, or resizable.
- Candidate `desktopIconWindow + 1` passed manual desktop, Finder, drag, resize, Spaces, and full-screen checks.
- Multi-monitor behavior is untested because no second monitor is available.
- Display sleep/wake and display scaling/resolution behavior are intentionally deferred beyond the stack decision.

Source verification from the local macOS SDK supports the APIs used by the prototype:

- `NSWindow.level` and `NSWindow.collectionBehavior` exist in the AppKit SDK headers.
- `NSWindowCollectionBehaviorStationary` is documented in the local SDK header as unaffected by Expose and stationary like a desktop window.
- `NSWindowCollectionBehaviorCanJoinAllSpaces`, `NSWindowCollectionBehaviorIgnoresCycle`, and `NSWindowCollectionBehaviorFullScreenAuxiliary` are available AppKit collection behaviors.
- `CGWindowLevelForKey` and `kCGDesktopIconWindowLevelKey` exist in CoreGraphics SDK headers.

Evidence files:

- `tasks/feasibility-evaluation-2026-07-01.md`
- `tasks/feasibility-acceptance-checklist.md`
- `docs/models/deskblocks-state-model.md`
- `Sources/DeskBlocksPrototype/main.swift`
- `Sources/DeskBlocksCore/TileGridMetrics.swift`

## Decision

Accept Swift/AppKit as the DeskBlocks MVP app stack.

Continue with the current architecture shape:

- `DeskBlocksCore` owns deterministic geometry, snapping, persisted state, and future folder-reference invariants.
- AppKit owns macOS windows, pointer interaction, rendering, and desktop behavior.
- The current desktop-overlay candidate is `CGWindowLevelForKey(.desktopIconWindow) + 1` with `.canJoinAllSpaces`, `.stationary`, `.ignoresCycle`, and `.fullScreenAuxiliary`.
- Swift Package Manager remains the current build/run mechanism until packaging work requires a different project structure.

This decision does not approve broad OS integrations, login items, accessibility permissions, Finder file operations, or external services. Those still require explicit approval and separate documentation.

## Alternatives Considered

### Electron

- Pros: Fast UI iteration, familiar web tooling, large npm ecosystem, Chromium DevTools.
- Cons: Adds a Chromium/App shell for a macOS-only utility whose main risk is native desktop window behavior; desktop-level overlay behavior would still require native validation; higher idle footprint risk.
- Rejected for MVP: The Swift/AppKit prototype already proves the key desktop behavior without introducing Chromium.

### Tauri

- Pros: Smaller footprint than Electron while keeping web UI ergonomics.
- Cons: Still adds a webview layer and native bridge around a problem that is primarily AppKit window behavior; desktop overlay behavior would still need native proof.
- Rejected for MVP: It does not reduce the primary risk compared with the now-proven Swift/AppKit path.

### Keep Stack Undecided And Test More

- Pros: More evidence before commitment.
- Cons: The required feasibility checks for the current decision are complete; more stack exploration would delay MVP work without a specific blocking concern.
- Rejected: Remaining checks are either intentionally deferred or not available on the current hardware.

## Consequences

- MVP planning can proceed on Swift/AppKit.
- The project should continue separating deterministic core logic from AppKit UI behavior.
- Electron and Tauri should not be revisited unless Swift/AppKit hits a concrete blocker.
- Mission Control behavior must be treated as a known limitation: DeskBlocks does not enter Mission Control as a normal managed window and remains on the desktop while other windows move forward.
- Multi-monitor behavior remains unknown until a second display is available.
- Display sleep/wake and display scaling/resolution behavior are follow-up validation items, not stack-decision blockers.
- `SPEC.md` and `AGENTS.md` must now describe Swift/AppKit as the accepted MVP stack.
- Packaging, signing, app bundle structure, and distribution are separate future decisions.

