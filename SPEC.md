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

- Swift/AppKit is accepted as the MVP app stack by `docs/decisions/ADR-002-accept-swift-appkit-for-mvp.md`.
- The current implementation uses Swift/AppKit via Swift Package Manager.
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

Current MVP calibration candidate:

- Tile slot: `112x104` points.
- Tile slot includes the native macOS system folder icon and a single-line label for readability checks.
- Default `4x3` block content size: `472x370` points including padding and title area.

### Folder Reference Tile

A future tile may contain a reference to a Finder folder. DeskBlocks should treat this as an app-owned visual reference, not as ownership of the folder itself.

When a folder reference is placed in a tile:

- DeskBlocks stores bookmark-backed folder reference data, with the last known path kept only as secondary fallback/debug metadata.
- DeskBlocks stores the tile index for the reference so a folder can occupy a specific visible tile slot.
- DeskBlocks renders the folder as a tile item inside the block.
- DeskBlocks can open the referenced folder through the system workspace.
- Moving the block moves the rendered tile item with the block.
- Resizing the block may change which tile slots are visible or available, but must not scale the tile item.
- Removing a folder reference clears only the DeskBlocks tile reference.
- This reference-only rule also applies to top-level folders that are located directly on the Desktop.
- DeskBlocks must not move, rename, copy, delete, or reorganize the underlying Finder folder as part of this behavior.

### Magnetic Tile Placement

Magnetic tile placement is a future interaction candidate: when the user drags a Finder folder near or into a DeskBlocks tile, the folder reference subtly snaps into that tile.

This should be implemented as DeskBlocks accepting a folder reference through drag and drop, not as DeskBlocks manipulating the real Finder desktop icon position. The snap should feel gentle and predictable, and it must be possible to remove the reference from the tile without deleting or moving the underlying folder.

Current MVP behavior uses a small magnetic margin around visible tile slots and a subtle neutral hover treatment while a Finder folder is dragged near a valid target tile.

### Resize Behavior

When the user resizes a block:

- The block frame resizes in whole-tile increments.
- The tile size does not change.
- The visible column and row count updates based on available block size.
- The block must not end in a half-tile state.
- Minimum size must be at least one usable tile plus title and frame chrome.

## UX Direction

DeskBlocks should feel native to macOS and follow an Apple-like visual style: quiet controls, system typography, restrained borders, and no decorative UI that competes with the desktop.

MVP UX decisions:

- The app starts as a normal Dock app, not a menu bar-only app.
- Block creation happens through the app menu, starting with `File > New Block...`.
- `File > New Block...` asks for a block title and a total tile count.
- The total tile count is converted into a near-square grid: perfect squares stay square, and non-squares increase the column count first before adding another row.
- For non-square counts, the frame may contain unused geometric capacity, but DeskBlocks must render only the requested tile slots. Example: `10` requested tiles creates a `4x3` frame capacity while showing only `10` tile slots; the remaining capacity stays blank.
- Blocks are visually transparent wherever there is no frame, text, icon, button, resize affordance, or explicit hover/selection UI.
- Transparency is optical only for the MVP. Empty transparent block areas do not need to pass clicks through to Finder.
- Blocks should be moved by dragging the title/frame area, not by relying on the empty transparent interior.
- Resize should use Apple-like window edge/corner behavior or subtle visible handles.
- Block windows should not support maximize/zoom or minimize in the MVP; they are desktop organization surfaces, not document windows.
- A block must never resize below the minimum snapped size needed to display its current tile count.
- When a block is widened enough to fit the current tile count in fewer rows, empty trailing rows may be removed by reducing height.
- A block viewport must show at most 10 full tile rows and at most 10 full tile columns.
- If a block contains more tile slots than the current viewport can show, the block must show subtle overflow indicators and allow scrolling to hidden tiles.
- Overflow indicators get dedicated vertical breathing room above and below the tile grid rather than overlapping tile content.
- A block must not resize beyond the visible screen bounds from its current screen position.
- Title editing should use a minimal native interaction such as double-clicking the title or a context menu action.
- Users can add or delete tile slots in a block; deleting tiles must never reduce a block below one tile.
- Block removal should use a context menu or a subtle hover/selection control.

## MVP Scope

The MVP should prove the desktop-block interaction model before broad customization.

Required MVP capabilities:

- Create a block with a title.
- Create a block through `File > New Block...`.
- Choose a block's initial tile count during creation.
- Add or delete tile slots after block creation.
- Show the block on the macOS desktop as a visual overlay.
- Drag a block to reposition it.
- Resize a block with pointer interaction.
- Snap block size to whole tile rows and columns.
- Prevent resize states where current tile slots disappear because the block capacity is too small.
- Persist block title, position, size, and tile count across app restarts.
- Render at least one block with fixed tile slots that visually match Finder folder readability.
- Preserve the model that tile contents are DeskBlocks references, not Finder file ownership.
- Place a folder reference into a visible tile through a minimal native interaction.
- Place a folder reference by dragging a Finder folder onto a visible tile.
- Show a subtle magnetic target highlight when a dragged Finder folder is near a valid tile.
- Open and remove a folder reference from a visible tile without changing the Finder folder.
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

The macOS app stack is Swift/AppKit for the MVP.

This was selected after feasibility evidence, not by preference alone. ADR-002 records the decision and rejects Electron and Tauri for the MVP unless Swift/AppKit hits a concrete blocker.

The accepted stack must continue to support:

- Transparent or visually lightweight desktop-level windows.
- Reliable window level behavior around the desktop and Finder.
- Pointer drag and resize.
- Whole-tile size snapping.
- Position and size persistence.
- Future folder-reference persistence and drag-and-drop feasibility before implementing magnetic tile placement.
- Acceptable startup and idle resource usage for a private utility app.

Major future stack or architecture changes must be recorded in `docs/decisions/` as ADRs before implementation.

Folder references use bookmark-backed persistence as accepted in `docs/decisions/ADR-003-use-bookmarks-for-folder-references.md`. Plain paths are not the primary identity for folder tiles.

## Commands

Current prototype commands:

- Build: `swift build`
- Run: `swift run DeskBlocksPrototype`
- Check core geometry: `swift run DeskBlocksCoreChecks`
- Smoke folder-reference placement: `swift run DeskBlocksPrototype --add-folder-smoke "/path/to/folder" --tile-index 0`
- Smoke folder-reference removal: `swift run DeskBlocksPrototype --remove-folder-smoke --tile-index 0`

No lint or packaging command exists yet.

The current Command Line Tools setup does not provide an importable XCTest module for SwiftPM tests. Until that changes, core grid and snapping checks run through `swift run DeskBlocksCoreChecks`.

Do not claim any of the following exist until matching project files have been added:

- `npm run dev`
- `npm run build`
- `npm test`
- `swift test`
- `cargo test`

When lint or packaging commands exist, update this section and `AGENTS.md` with the exact commands.

## Project Structure

Current intended structure:

- `AGENTS.md` - durable Codex project guidance.
- `SPEC.md` - product and technical source of truth.
- `docs/` - supporting project documentation, ADRs, and lightweight models.
- `agents/` - copied role guidance for review/testing/security/performance.
- `skills/` - copied local reference workflows.
- `references/` - copied local checklists.
- `Package.swift` - SwiftPM package for the Swift/AppKit feasibility prototype.
- `Sources/DeskBlocksCore/` - pure Swift geometry and snapping logic.
- `Sources/DeskBlocksCoreChecks/` - executable checks for grid and snapping invariants.
- `Sources/DeskBlocksPrototype/` - current Swift/AppKit MVP prototype source.
  - `AppConfiguration.swift` - overlay level, prototype geometry, and AppKit/Core conversion helpers.
  - `PrototypeStateStore.swift` - JSON load/save for the private prototype.
  - `DeskBlockView.swift` - block rendering, tile rendering, and block context menu.
  - `AppDelegate.swift` - AppKit lifecycle, menus, dialogs, windows, and state orchestration.
  - `DeskBlocksPrototype.swift` - executable entry point.
- `docs/decisions/` - ADRs for durable technical choices.
- `docs/models/` - lightweight product and state models that clarify invariants.
- `tasks/` - implementation plans, task checklists, and feasibility evidence.

## Code Style

- Prefer simple, explicit code over clever abstractions.
- Keep desktop behavior, grid math, folder-reference state, persistence, and UI rendering as separable concerns.
- Put core grid and snapping math in testable pure logic where the selected stack allows it.
- Use clear names for block geometry, tile dimensions, rows, columns, and snapped sizes.
- Represent tile contents as references owned by DeskBlocks UI state, not as Finder file operations.
- Keep folder-reference identity, display metadata, and tile placement explicit in the core model.
- Do not introduce broad abstractions until at least two concrete uses justify them.

## Testing Strategy

Before full MVP implementation, the feasibility prototype must include manual verification evidence for macOS desktop behavior.

Test at these levels:

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

- Should the current `112x104` point tile slot remain the MVP value after real folder-reference tiles or additional display setups are tested?
- Should the current `desktopIconWindow + 1` level remain acceptable after longer daily-use testing or multi-monitor validation?
- Should persistence remain plain JSON for the private MVP, or move to a macOS-native format later?
- Magnetic placement currently covers subtle drag targeting and hover highlighting. Stronger animation, preview positioning, or non-tile-area snapping remains open.

## Confidence

Confidence score: 88%.

Reason:

- Product intent, MVP direction, non-goals, accepted MVP stack, and first technical risk are clear from the existing project conversation, feasibility evidence, `AGENTS.md`, and ADR-002.
- Longer daily-use window behavior, multi-monitor behavior, magnetic tile placement, and any later persistence-store change remain unresolved because they require focused implementation evidence rather than guessing.
