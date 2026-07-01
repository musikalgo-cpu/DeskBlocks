# Spec: DeskBlocks

## Objective

DeskBlocks is a private macOS desktop app for visually organizing the desktop with user-created blocks. Each block provides a title, a visible frame, and a fixed-size tile grid sized for Finder folder icons plus labels.

The core product idea is not a dashboard and not a window manager. DeskBlocks should make groups of desktop folders easier to see and maintain by adding visual structure around them.

Primary user:

- A single macOS user organizing their own desktop.

Primary success:

- The user can create, position, and resize visual blocks on the desktop.
- Tile size remains constant so folders and labels stay readable.
- Resizing changes the number of visible tile slots, not the tile scale.
- The app behaves reliably enough on macOS to justify building the full MVP.

## Current Project State

- No production app stack is selected yet.
- The first feasibility prototype uses Swift/AppKit via Swift Package Manager.
- Prototype source exists under `Sources/DeskBlocksPrototype/` and `Sources/DeskBlocksCore/`.
- Build, run, and core geometry check commands exist for the prototype.
- No lint or packaging commands exist yet.
- Current repository content is project guidance, copied reference skills, reference checklists, and this spec.

## Product Model

### Block

A block is a visual desktop container with:

- Title text.
- Visible border or frame.
- Position on screen.
- Width and height.
- Fixed-size tile grid.
- Resize affordances similar to normal windows.

Blocks are organizational overlays. They do not own, move, copy, delete, or sync Finder files in the MVP.

### Tile

A tile is a fixed-size visual slot intended to fit:

- A Finder folder icon.
- The folder label below the icon.
- Comfortable spacing so the label remains readable.

Tile dimensions are a product invariant. The first implementation must choose tile dimensions through measurement in the feasibility prototype, not by guessing.

### Folder Reference Tile

A future tile may contain a reference to a Finder folder. DeskBlocks should treat this as an app-owned visual reference, not as ownership of the folder itself.

When a folder reference is placed in a tile:

- DeskBlocks stores a durable reference to the folder path or alias-like identifier.
- DeskBlocks renders the folder as a tile item inside the block.
- Moving the block moves the rendered tile item with the block.
- Resizing the block may change which tile slots are visible or available, but must not scale the tile item.
- This reference-only rule also applies to top-level folders that are located directly on the Desktop.
- DeskBlocks must not move, rename, copy, delete, or reorganize the underlying Finder folder as part of this behavior.

### Magnetic Tile Placement

Magnetic tile placement is a future interaction candidate: when the user drags a Finder folder near or into a DeskBlocks tile, the folder reference subtly snaps into that tile.

This should be implemented as DeskBlocks accepting a folder reference through drag and drop, not as DeskBlocks manipulating the real Finder desktop icon position. The snap should feel gentle and predictable, and it must be possible to remove the reference from the tile without deleting or moving the underlying folder.

This feature is not part of the current feasibility prototype. It should be documented now because it affects the future persistence model and the final app-stack decision.

### Resize Behavior

When the user resizes a block:

- The block frame resizes in whole-tile increments.
- The tile size does not change.
- The visible column and row count updates based on available block size.
- The block must not end in a half-tile state.
- Minimum size must be at least one usable tile plus title and frame chrome.

## MVP Scope

The MVP should prove the desktop-block interaction model before broad customization.

Required MVP capabilities:

- Create a block with a title.
- Show the block on the macOS desktop as a visual overlay.
- Drag a block to reposition it.
- Resize a block with pointer interaction.
- Snap block size to whole tile rows and columns.
- Persist block title, position, size, and tile count across app restarts.
- Render at least one block with fixed tile slots that visually match Finder folder readability.
- Preserve the model that tile contents are DeskBlocks references, not Finder file ownership.
- Provide a minimal way to edit a block title and remove a block.

Feasibility prototype capabilities:

- Create one hard-coded block.
- Show it with transparent or visually non-disruptive desktop-level behavior.
- Prove drag, resize, whole-tile snapping, and persistence.
- Document whether the tested stack can meet the macOS desktop behavior requirements.

## Non-Goals

DeskBlocks MVP will not:

- Replace Finder.
- Move or manage files directly.
- Move real Finder desktop icons as part of magnetic tile placement.
- Provide a full dashboard, calendar, task manager, or command center.
- Implement multi-user or cloud sync.
- Support Windows or Linux.
- Support complex themes, widgets, automation, or scripting.
- Require broad OS permissions unless the feasibility prototype proves they are necessary and the user approves.

## Technical Strategy

The first technical decision is the macOS app stack. It must not be selected by preference alone.

Candidate stacks:

- Swift/AppKit.
- Electron.
- Tauri.

The first feasibility work must compare whether the selected candidate can support:

- Transparent or visually lightweight desktop-level windows.
- Reliable window level behavior around the desktop and Finder.
- Pointer drag and resize.
- Whole-tile size snapping.
- Position and size persistence.
- Future folder-reference persistence and drag-and-drop feasibility, if magnetic tile placement remains in scope before the final stack decision.
- Acceptable startup and idle resource usage for a private utility app.

Major stack decisions must be recorded in `docs/decisions/` as ADRs before full MVP implementation.

## Commands

Current prototype commands:

- Build: `swift build`
- Run: `swift run DeskBlocksPrototype`
- Check core geometry: `swift run DeskBlocksCoreChecks`

No lint or packaging command exists yet.

The current Command Line Tools setup does not provide an importable XCTest module for SwiftPM tests. Until that changes, core grid and snapping checks run through `swift run DeskBlocksCoreChecks`.

Do not claim any of the following exist until matching project files have been added:

- `npm run dev`
- `npm run build`
- `npm test`
- `swift test`
- `cargo test`

When the app stack is accepted for MVP work, update this section and `AGENTS.md` with exact commands for development, build, lint, test, and packaging.

## Project Structure

Current intended structure:

- `AGENTS.md` - durable Codex project guidance.
- `SPEC.md` - product and technical source of truth.
- `docs/` - supporting project documentation and future ADRs.
- `agents/` - copied role guidance for review/testing/security/performance.
- `skills/` - copied local reference workflows.
- `references/` - copied local checklists.
- `Package.swift` - SwiftPM package for the Swift/AppKit feasibility prototype.
- `Sources/DeskBlocksCore/` - pure Swift geometry and snapping logic.
- `Sources/DeskBlocksCoreChecks/` - executable checks for grid and snapping invariants.
- `Sources/DeskBlocksPrototype/` - current prototype source.

Expected future additions:

- `docs/decisions/` - ADRs for durable technical choices.
- `tasks/plan.md` - implementation plan.
- `tasks/todo.md` - task checklist.
- Source directories based on the selected app stack.

## Code Style

No project language or framework exists yet.

When a stack is selected:

- Prefer simple, explicit code over clever abstractions.
- Keep desktop behavior, grid math, folder-reference state, persistence, and UI rendering as separable concerns.
- Put core grid and snapping math in testable pure logic where the selected stack allows it.
- Use clear names for block geometry, tile dimensions, rows, columns, and snapped sizes.
- Represent tile contents as references owned by DeskBlocks UI state, not as Finder file operations.
- Do not introduce broad abstractions until at least two concrete uses justify them.

## Testing Strategy

Before full MVP implementation, the feasibility prototype must include manual verification evidence for macOS desktop behavior.

When a stack exists, test at these levels:

- Unit tests for tile grid math, snapped resize dimensions, minimum sizes, and persistence serialization.
- Integration tests where practical for block state loading and saving.
- Manual runtime checks for desktop window behavior that automated tests cannot reliably prove.
- UI or browser-based checks only if the selected stack uses web UI technology.

Required test scenarios for grid math:

- Width and height snap to whole tile counts.
- Minimum size never drops below one usable tile.
- Resizing up increases rows or columns predictably.
- Resizing down removes only whole rows or columns.
- Tile size remains unchanged across resize operations.

Required manual scenarios for the feasibility prototype:

- App launches and shows a block on the macOS desktop.
- Block can be dragged.
- Block can be resized.
- Resize snapping is visible and stable.
- Block state persists after quitting and reopening the app.
- Block does not make normal desktop use unacceptably difficult.

## Boundaries

Always:

- Keep fixed tile size as a core invariant.
- Treat macOS desktop behavior as the first implementation risk.
- Update this spec when scope or product decisions change.
- Use `references/definition-of-done.md` before considering work complete.

Ask first:

- Choosing the app stack.
- Adding dependencies.
- Adding OS-level permissions, login items, automation, or accessibility integrations.
- Changing persistence format.
- Adding folder drag-and-drop or magnetic tile placement behavior.
- Expanding beyond visual desktop organization.

Never:

- Implement file-moving or destructive Finder behavior in the MVP.
- Move real Finder icons or underlying folders when moving a DeskBlocks block.
- Add cloud services or external sync without explicit approval.
- Claim build/test commands exist before the project has matching files.
- Copy unrelated source-project product context into DeskBlocks.

## Success Criteria

Feasibility prototype is successful when:

- One block can be displayed on the macOS desktop.
- The block can be dragged and resized by pointer interaction.
- Resize behavior snaps to whole tile rows and columns.
- Tile size remains constant.
- Block title, position, and size persist across restart.
- The implementation path is documented with a recommendation to continue, change stack, or stop.

MVP is successful when:

- A user can create multiple named blocks.
- Blocks can be positioned and resized independently.
- All blocks restore correctly after app restart.
- Folder references, when implemented, move visually with their containing block.
- The UI remains quiet and desktop-focused.
- No MVP behavior requires the app to manage user files.

## Open Questions

- What exact tile dimensions best match Finder folder icon and label readability on the user's display?
- Should blocks live behind Finder icons, above Finder icons, or as a normal utility window layer? This must be proven on macOS.
- Should block creation happen through a menu bar app, a floating control, or direct desktop interaction?
- What persistence format should be used after the stack is selected?
- Should folder references be stored as paths, aliases, bookmarks, or another macOS-native reference type?
- Should magnetic tile placement be tested before the final stack ADR, or deferred until after the basic block MVP is proven?
- Should Swift/AppKit continue after feasibility evidence, or should Electron/Tauri be tested next?

## Confidence

Confidence score: 84%.

Reason:

- Product intent, MVP direction, non-goals, and first technical risk are clear from the existing project conversation and `AGENTS.md`.
- Exact tile dimensions, stack choice, and macOS window-layer behavior are intentionally unresolved because they require measurement or feasibility testing rather than guessing.
