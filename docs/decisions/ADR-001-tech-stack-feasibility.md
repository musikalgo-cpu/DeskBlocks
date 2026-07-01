# ADR-001: Prove macOS Desktop Feasibility Before Choosing the App Stack

## Status

Accepted

## Date

2026-07-01

## Context

DeskBlocks is a private macOS desktop app for visual desktop organization. The core user experience depends on blocks that appear on the desktop, can be dragged and resized, and snap to whole fixed-size tile rows and columns.

The hard problem is not the grid math. The hard problem is whether the selected app stack can behave correctly on macOS as a desktop-level visual utility without making normal desktop use worse.

Key requirements from `SPEC.md`:

- Show a block on the macOS desktop as a visual overlay.
- Support pointer dragging and resizing.
- Snap resize dimensions to whole tile rows and columns.
- Keep tile size constant.
- Persist title, position, and size across app restarts.
- Avoid file-moving or destructive Finder behavior in the MVP.

No app stack has been chosen yet. The candidate stacks are Swift/AppKit, Electron, and Tauri.

## Decision

Do not choose the production app stack yet.

First, build a focused feasibility prototype that proves the macOS desktop behavior required by DeskBlocks. The prototype should be intentionally small: one hard-coded block, fixed tile dimensions, drag, resize, whole-tile snapping, and persistence.

The first prototype candidate is Swift/AppKit using the currently available Command Line Tools, Swift compiler, and macOS SDK. This is not a production stack decision; it is the first test because the core risk is native macOS window behavior.

The stack decision will be made after prototype evidence is collected and documented. The decision must be recorded in a later ADR that either accepts a stack or rejects the current direction.

## Alternatives Considered

### Choose Swift/AppKit immediately

- Pros: Native macOS window APIs, likely strongest fit for desktop-level behavior.
- Cons: Still needs proof for Finder/desktop layering, transparent windows, and interaction model.
- Rejected for now: Native preference is plausible but should be proven before full MVP work.

### Choose Electron immediately

- Pros: Fast UI iteration and familiar web tooling.
- Cons: Desktop-level window behavior, idle resource use, and macOS integration may be weak for this utility.
- Rejected for now: The app's main risk is OS behavior, not UI speed.

### Choose Tauri immediately

- Pros: Smaller footprint than Electron with web UI ergonomics.
- Cons: Desktop-level macOS behavior still needs proof, and native window control may require extra integration.
- Rejected for now: It may be viable, but the key macOS behavior must be tested.

### Build the full MVP first

- Pros: Produces visible user value sooner if assumptions are correct.
- Cons: Risks building product logic on a stack that cannot satisfy the core desktop behavior.
- Rejected: The feasibility risk is too central to defer.

## Feasibility Criteria

The prototype is successful only if it demonstrates:

- A block can be displayed in a desktop-appropriate macOS layer.
- The block does not make normal desktop use unacceptably difficult.
- The block can be repositioned with pointer interaction.
- The block can be resized with pointer interaction.
- Resize dimensions snap to whole tile rows and columns.
- Tile size remains constant during resize.
- Block title, position, and size persist after quitting and reopening.
- The implementation path is simple enough to justify continued MVP work.

The prototype must also document:

- Which stack was tested.
- Which macOS window level or desktop behavior was used.
- Any required permissions or OS settings.
- Known limitations around Finder icons, Spaces, Mission Control, multi-monitor behavior, or full-screen apps.

## Consequences

- MVP implementation waits until the feasibility prototype has evidence.
- The first implementation tasks should optimize for learning, not polish.
- Some open questions in `SPEC.md` will remain open until the prototype is tested.
- A later ADR must record the final app stack decision.
- `AGENTS.md` and `SPEC.md` must be updated once real dev/build/test commands and project structure exist.

## Next Steps

- Create `tasks/plan.md` for the feasibility phase.
- Create `tasks/todo.md` with small, verifiable tasks.
- Decide which candidate stack to prototype first before writing application code.
