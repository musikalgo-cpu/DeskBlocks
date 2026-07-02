# Implementation Plan: DeskBlocks MVP

## Overview

Build the first real Swift/AppKit MVP from the proven feasibility prototype. The MVP should support multiple visual desktop blocks with fixed-size tile grids, basic block creation/removal, title editing, drag/resize with whole-tile snapping, and persistence across restart. Folder-reference tiles and magnetic placement remain deferred until the basic block model is stable.

## Architecture Decisions

- Swift/AppKit is the MVP app stack, accepted in `docs/decisions/ADR-002-accept-swift-appkit-for-mvp.md`.
- Keep the deterministic-core/UI-shell split from `docs/models/deskblocks-state-model.md`.
- Keep `DeskBlocksCore` responsible for block state, tile geometry, snapping, validation, and persistence-safe data structures.
- Keep AppKit responsible for windows, pointer interaction, rendering, menus/controls, and macOS desktop behavior.
- Keep the current JSON persistence approach unless a later task explicitly justifies a persistence-format ADR.
- Use Apple-like native macOS UX: normal Dock app, `File > New Block...` for creation, subtle native controls, and optical transparency outside frame/text/buttons/handles.
- `File > New Block...` asks for title and total tile count. The core converts tile count to a near-square grid by using perfect squares when possible and increasing columns first for non-squares.
- Treat transparent empty block areas as visually transparent only for the MVP; click-through to Finder is not required.

## Phase 1: MVP Foundation

### Task 1: Decide MVP Block Creation UX

**Description:** Choose the minimal user-facing way to create a new block. The current open options are app menu, menu bar item, floating control, or direct desktop interaction.

**Acceptance criteria:**
- [x] One MVP creation path is selected: `File > New Block...` in a normal Dock app.
- [x] Rejected options are briefly documented with rationale.
- [x] The selected path does not require unapproved OS permissions or external services.

**Decision notes:**
- Menu bar-only app is deferred because the MVP should avoid lifecycle and status-item complexity.
- Floating control is deferred because it adds permanent UI chrome before the block interaction model is proven.
- Direct desktop interaction is deferred because it would require more custom hit-testing and risks conflicting with Finder behavior.
- Optical transparency is required outside frame/text/buttons/handles, but transparent empty areas do not need Finder click-through in the MVP.

**Verification:**
- [x] Update `SPEC.md` if the chosen creation UX changes product behavior.
- [x] Record an ADR only if the choice creates durable architecture constraints.

**Dependencies:** None

**Files likely touched:**
- `SPEC.md`
- `docs/decisions/`
- `tasks/mvp-plan.md`

**Estimated scope:** S

### Task 2: Model Multiple Blocks In Core

**Description:** Extend the core state from one block toward a collection of blocks with stable identifiers, valid frames, titles, snapped sizes, and future tile references.

**Acceptance criteria:**
- [x] Core state can represent multiple blocks with stable IDs.
- [x] Every block remains snapped through `TileGridMetrics`.
- [x] Invalid loaded block sizes are normalized before rendering.

**Verification:**
- [x] Add executable checks to `DeskBlocksCoreChecks`.
- [x] Run `swift run DeskBlocksCoreChecks`.
- [x] Run `swift build`.

**Dependencies:** None

**Files likely touched:**
- `Sources/DeskBlocksCore/`
- `Sources/DeskBlocksCoreChecks/`
- `docs/models/deskblocks-state-model.md`

**Estimated scope:** M

### Task 3: Persist Multiple Blocks

**Description:** Save and restore the multiple-block state using the current JSON persistence approach without changing the persistence format family.

**Acceptance criteria:**
- [x] Multiple blocks survive quit and relaunch.
- [x] Block IDs, titles, positions, sizes, and tile-reference arrays round-trip.
- [x] Decode failure still falls back safely without file-moving behavior.

**Verification:**
- [x] Add persistence round-trip checks to `DeskBlocksCoreChecks`.
- [x] Run `swift run DeskBlocksCoreChecks`.
- [x] Run `swift build`.
- [x] Manual relaunch smoke check with `swift run DeskBlocksPrototype`.

**Dependencies:** Task 2

**Files likely touched:**
- `Sources/DeskBlocksCore/`
- `Sources/DeskBlocksCoreChecks/`
- `Sources/DeskBlocksPrototype/`

**Estimated scope:** M

## Checkpoint: Core MVP State

- [x] Multiple-block core checks pass.
- [x] Persistence checks pass.
- [x] No Finder file operations were introduced.
- [ ] `docs/models/deskblocks-state-model.md` matches the implemented lifecycle.

## Phase 2: Desktop Block Interactions

### Task 4: Render Multiple Blocks As AppKit Windows

**Description:** Replace the one hard-coded block window with rendering from persisted block state. Each block should be draggable and resizable independently.

**Acceptance criteria:**
- [x] All persisted blocks render after launch.
- [x] Moving one block does not move or resize another block.
- [x] Resizing one block snaps through core logic and persists.

**Verification:**
- [x] Run `swift run DeskBlocksCoreChecks`.
- [x] Run `swift build`.
- [x] Manual launch, move, resize, quit, relaunch check.
- [x] Automated Window Server smoke check saw two DeskBlocks windows from a temporary two-block persisted state, including after relaunch.
- [x] Close crash fixed and guarded with `swift run DeskBlocksPrototype --close-smoke`.

**Dependencies:** Task 3

**Files likely touched:**
- `Sources/DeskBlocksPrototype/`
- `Sources/DeskBlocksCore/`

**Estimated scope:** M

### Task 5: Add Minimal Block Creation

**Description:** Implement the selected MVP block creation path from Task 1 and create a valid default snapped block.

**Acceptance criteria:**
- [x] User can create a new block through the selected dialog path.
- [x] New blocks get unique IDs and user-provided titles.
- [x] New blocks derive columns and rows from total tile count.
- [x] Non-square tile counts preserve requested visible slots instead of filling all frame capacity.
- [x] New blocks persist after restart.

**Verification:**
- [x] Run `swift run DeskBlocksCoreChecks`.
- [x] Run `swift build`.
- [x] Automated creation smoke check with `swift run DeskBlocksPrototype --new-block-title "Ten Tiles" --new-block-smoke 10`.
- [x] Regression check confirms `10` requested tiles use `4x3` frame capacity while rendering only `10` slots.
- [x] Manual `File > New Block...` dialog, quit, relaunch check.

**Implementation notes:**
- `File > New Block...` is wired through the AppKit main menu.
- The previous immediate-default-block creation was replaced with a native dialog for title and total tile count.
- `10` tiles currently produces a `4x3` frame through the core tile-count layout rule, but only `10` tile slots render; the unused frame capacity stays blank.
- A native close crash during quit/relaunch validation was fixed by retaining AppKit windows through close and avoiding window reference cleanup during AppKit's close callback.

**Dependencies:** Task 1, Task 4

**Files likely touched:**
- `Sources/DeskBlocksPrototype/`
- `Sources/DeskBlocksCore/`

**Estimated scope:** M

### Task 6: Add Title Editing

**Description:** Provide a minimal way to rename a block while preserving snapped size, position, and tile references.

**Acceptance criteria:**
- [x] User can edit a block title.
- [x] Empty or invalid title input is handled predictably.
- [x] Edited titles persist after restart.

**Verification:**
- [x] Add core checks for title validation if validation is introduced.
- [x] Run `swift run DeskBlocksCoreChecks`.
- [x] Run `swift build`.
- [x] Manual rename, quit, relaunch check.

**Implementation notes:**
- Rename is available through `Edit > Rename Block...`, block-title double-click, and the block context menu.
- Empty or whitespace-only titles are rejected by preserving the previous title.
- Automated rename persistence is guarded with `swift run DeskBlocksPrototype --rename-smoke "Title"`.
- The current prototype has no installed `.app` relaunch path; after quitting, relaunch is still done through `swift run DeskBlocksPrototype` until packaging/app-bundle work exists.

**Dependencies:** Task 4

**Files likely touched:**
- `Sources/DeskBlocksPrototype/`
- `Sources/DeskBlocksCore/`

**Estimated scope:** M

### Task 7: Add Block Removal

**Description:** Provide a minimal way to remove a block from DeskBlocks state without deleting, moving, or changing any Finder files.

**Acceptance criteria:**
- [x] User can remove a block.
- [x] Removed blocks do not return after restart.
- [x] Removing a block never deletes or moves real folders.

**Verification:**
- [x] Add core checks for remove behavior.
- [x] Run `swift run DeskBlocksCoreChecks`.
- [x] Run `swift build`.
- [x] Automated remove smoke check with `swift run DeskBlocksPrototype --remove-smoke`.
- [x] Automated last-block removal check confirms intentionally empty persisted state stays empty after launch.
- [x] Manual remove, quit, relaunch check.

**Implementation notes:**
- Removal is available through `Edit > Remove Block...` and the block context menu.
- Removal requires a native confirmation dialog and states that Finder folders and files are not changed.
- Core removal keeps non-removed blocks unchanged, ignores unknown block IDs, and allows the last block to be removed from the current app state.
- If the last block is removed, DeskBlocks keeps the intentionally empty persisted state across restart. A missing state file still creates the first default block.

**Dependencies:** Task 4

**Files likely touched:**
- `Sources/DeskBlocksPrototype/`
- `Sources/DeskBlocksCore/`
- `Sources/DeskBlocksCoreChecks/`

**Estimated scope:** M

## Checkpoint: Usable MVP Blocks

- [x] User can create, rename, move, resize, remove, quit, and relaunch.
- [x] Current create/move/resize state restores correctly.
- [x] Manual desktop behavior remains acceptable with multiple blocks.
- [ ] `references/definition-of-done.md` is satisfied for implemented slices.

## Phase 3: Visual Calibration And Review

### Task 8: Calibrate Tile Visuals For Finder Readability

**Description:** Measure and adjust tile dimensions and block chrome so folder icon and label readability are plausible on the user's display.

**Acceptance criteria:**
- [x] Tile dimensions are documented as MVP values.
- [x] Fixed tile size remains unchanged during resize.
- [x] Labels and folder icons remain readable enough for the MVP direction.

**Verification:**
- [x] Run `swift run DeskBlocksCoreChecks`.
- [x] Run `swift build`.
- [x] Manual visual check on the user's desktop.

**Implementation notes:**
- Current MVP calibration candidate uses `112x104` point tile slots.
- A default `4x3` block is now `472x370` points including padding and title area.
- Empty prototype tiles render the native macOS system folder icon and `Folder` label so readability can be judged before real folder references exist.

**Dependencies:** Task 4

**Files likely touched:**
- `Sources/DeskBlocksCore/`
- `Sources/DeskBlocksPrototype/`
- `SPEC.md`

**Estimated scope:** S

### Task 9: Daily-Use Desktop Validation

**Description:** Re-test the accepted AppKit desktop behavior with multiple blocks and typical desktop use before considering the MVP interaction model complete.

**Acceptance criteria:**
- [ ] Multiple blocks remain usable around Finder icons.
- [ ] Mission Control limitation remains acceptable.
- [ ] Spaces and full-screen behavior remain acceptable.

**Verification:**
- [ ] Manual desktop test notes are captured in `tasks/`.
- [ ] Any new limitation is documented before continuing.

**Dependencies:** Tasks 5-8

**Files likely touched:**
- `tasks/`
- `SPEC.md` if product behavior changes

**Estimated scope:** S

### Task 10: MVP Review Gate

**Description:** Review the MVP against `SPEC.md`, ADR-002, the state model, and the Definition of Done before expanding into folder-reference or magnetic placement work.

**Acceptance criteria:**
- [ ] MVP scope items are checked against `SPEC.md`.
- [ ] Known limitations are documented.
- [ ] Next post-MVP feature decision is explicit: folder references, magnetic placement, packaging, or visual polish.

**Verification:**
- [ ] Run `swift run DeskBlocksCoreChecks`.
- [ ] Run `swift build`.
- [ ] Perform code/documentation review using `skills/code-review-and-quality/SKILL.md`.

**Dependencies:** Tasks 1-9

**Files likely touched:**
- `tasks/`
- `SPEC.md`
- `docs/decisions/`

**Estimated scope:** S

## Risks And Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Multiple AppKit windows make desktop behavior less stable | High | Re-test desktop/Finder/Spaces/full-screen behavior after Task 4 |
| Persistence grows implicit and hard to migrate | Medium | Keep state explicit in `DeskBlocksCore`; write an ADR before changing persistence format |
| Block creation UX adds too much UI too early | Medium | Choose one minimal creation path in Task 1 |
| Title editing or removal accidentally couples UI state to Finder files | High | Keep file operations out of MVP; tile references remain app-owned state only |
| Tile dimensions are guessed instead of measured | Medium | Calibrate in Task 8 before declaring the MVP interaction model complete |

## Deferred Beyond MVP

- Folder reference tiles.
- Magnetic tile placement.
- Real Finder icon manipulation.
- Login items, automation, accessibility permissions, and OS-level integrations.
- Packaging, signing, notarization, and distribution.
- Installed `.app` relaunch behavior; the current prototype is relaunched through `swift run DeskBlocksPrototype`.
- Multi-monitor validation until a second display is available.

## Open Questions

- Should the app stay as a normal dock app during MVP, or later become a menu bar app?
- What exact MVP tile dimensions should be accepted after visual calibration?
- Should persistence remain plain JSON for the private MVP, or move to a macOS-native format later?
