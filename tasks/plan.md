# Implementation Plan: DeskBlocks Feasibility Phase

## Overview

The first phase proves whether DeskBlocks can work as a macOS desktop-level visual utility before committing to a production app stack. The phase ends with evidence, an ADR for the stack decision, and updated project commands if a stack is accepted.

## Architecture Decisions

- Do not choose Swift/AppKit, Electron, or Tauri until feasibility evidence exists.
- First prototype candidate: Swift/AppKit using the currently available Command Line Tools, Swift compiler, and macOS SDK.
- Rationale: DeskBlocks' first risk is native macOS window behavior, and AppKit exposes `NSWindow` behavior directly. Electron and Tauri remain candidates if the native prototype fails or becomes too costly.
- Optimize the first prototype for learning, not product polish.
- Keep grid snapping logic separable from macOS window behavior so it can be tested and reused.
- Do not implement Finder file management in the feasibility phase.

## Phase 1: Feasibility Preparation

### Task 1: Decide first prototype stack candidate

**Description:** Choose which candidate stack to test first: Swift/AppKit, Electron, or Tauri. Use official documentation and the project constraints in `SPEC.md` and `docs/decisions/ADR-001-tech-stack-feasibility.md`.

**Acceptance criteria:**

- [x] One first-test stack is selected.
- [x] Selection rationale is documented.
- [x] Main risks for rejected first-test candidates are noted.

**Verification:**

- [x] Human approves the first-test candidate before implementation.

**Dependencies:** None

**Files likely touched:**

- `docs/decisions/ADR-001-tech-stack-feasibility.md`
- `tasks/todo.md`

**Estimated scope:** S

### Task 2: Define prototype acceptance checklist

**Description:** Convert the feasibility criteria into a runnable manual test checklist for the first prototype.

**Acceptance criteria:**

- [x] Checklist covers launch, desktop display, drag, resize, snapping, persistence, and normal desktop usability.
- [x] Checklist captures known macOS edge areas: Finder icons, Spaces, Mission Control, multi-monitor behavior, and full-screen apps.
- [x] Checklist includes fields for pass/fail notes.

**Verification:**

- [x] Checklist maps back to `SPEC.md` success criteria.

**Dependencies:** None

**Files likely touched:**

- `tasks/todo.md`
- Future prototype notes document, if needed

**Estimated scope:** S

## Checkpoint: Ready to Prototype

- [x] First prototype stack candidate is approved.
- [x] Prototype acceptance checklist exists.
- [ ] No full MVP work has started.

## Phase 2: Feasibility Prototype

### Task 3: Scaffold the minimum prototype

**Description:** Create the smallest runnable macOS app in the approved stack. It should launch and show a single hard-coded block.

**Acceptance criteria:**

- [x] App launches locally.
- [x] One visible block appears.
- [x] Project commands are documented in `SPEC.md` and `AGENTS.md`.

**Verification:**

- [x] Run the real launch/build command for the selected stack.
- [ ] Manual check: block is visible after launch.

**Dependencies:** Task 1

**Files likely touched:** Stack-dependent source and config files

**Estimated scope:** M

### Task 4: Implement fixed tile geometry and snapping logic

**Description:** Add the tile-size model and whole-tile resize snapping logic as isolated, testable behavior where the selected stack allows it.

**Acceptance criteria:**

- [x] Tile width and height are constants or clearly defined configuration.
- [x] Resize calculations snap to whole columns and rows.
- [x] Minimum block size is enforced.

**Verification:**

- [x] Unit tests or equivalent checks cover snap-up, snap-down, minimum size, and unchanged tile size.

**Dependencies:** Task 3

**Files likely touched:** Stack-dependent logic and test files

**Estimated scope:** M

### Task 5: Prove drag, resize, and persistence

**Description:** Make the prototype block draggable and resizable, then persist title, position, and size across restart. Keep the persistence model compatible with future tile contents, where folder tiles are DeskBlocks-owned references rather than moved Finder files.

**Acceptance criteria:**

- [x] Block can be dragged with pointer interaction.
- [x] Block can be resized with pointer interaction.
- [x] Resized dimensions remain snapped to whole tile rows and columns.
- [x] Block state restores after app restart.

**Verification:**

- [ ] Manual checklist passes for drag, resize, snapping, quit, and relaunch.
- [x] Automated persistence check exists through `swift run DeskBlocksCoreChecks`; launch smoke checks wrote and reloaded `~/Library/Application Support/DeskBlocks/prototype-state.json`.

**Dependencies:** Task 4

**Files likely touched:** Stack-dependent app, window, state, and persistence files

**Estimated scope:** M

### Task 6: Evaluate macOS desktop behavior

**Description:** Run the manual feasibility checklist and record evidence about desktop layering, Finder interaction, Spaces, Mission Control, multi-monitor behavior, permissions, and resource concerns.

**Acceptance criteria:**

- [ ] Manual checklist is completed with notes.
- [ ] Limitations are documented.
- [ ] Recommendation is clear: continue with stack, test another stack, or stop.

**Verification:**

- [ ] Human review of the evidence and recommendation.

**Dependencies:** Task 5

**Files likely touched:**

- `tasks/feasibility-evaluation-2026-07-01.md`
- `docs/decisions/` ADR follow-up

**Estimated scope:** S

## Checkpoint: Stack Decision

- [ ] Feasibility criteria have pass/fail evidence.
- [ ] A follow-up ADR records the app stack decision.
- [ ] `SPEC.md` and `AGENTS.md` list real commands if a stack is accepted.
- [ ] MVP planning does not begin until this checkpoint is complete.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Desktop-level window behavior is not reliable | High | Test before MVP work and switch stack if needed |
| Prototype over-expands into MVP | Medium | Keep one hard-coded block until feasibility is complete |
| Automated tests cannot prove OS behavior | Medium | Use manual checklist plus focused tests for pure logic |
| Web stack has unacceptable resource use | Medium | Capture startup/idle observations during feasibility |
| Tile dimensions are guessed incorrectly | Medium | Treat initial dimensions as prototype values and measure against Finder readability |
| Future magnetic tile placement changes persistence needs | Medium | Model tile contents as references, not file ownership, and decide drag/drop timing before the final stack ADR |

## Open Questions

- Which stack should be tested first?
- What exact tile dimensions should the first prototype use?
- Which macOS window layer is acceptable for normal desktop use?
- Should magnetic tile placement be tested before the final stack ADR or deferred until after the basic block MVP is proven?
