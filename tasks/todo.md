# DeskBlocks Todo

## Feasibility Preparation

- [x] Choose the first prototype stack candidate: Swift/AppKit.
- [x] Document the first-test stack rationale.
- [x] Create the manual prototype acceptance checklist.
- [x] Review checklist against `SPEC.md` and ADR-001.
- [x] Create explicit DeskBlocks state model.

## Feasibility Prototype

- [x] Scaffold the smallest runnable app in the selected stack.
- [x] Show one hard-coded block.
- [x] Define prototype tile dimensions.
- [x] Implement whole-tile resize snapping.
- [x] Add checks for snap-up, snap-down, minimum size, and unchanged tile size.
- [x] Keep persistence model compatible with future folder-reference tiles.
- [x] Add pointer drag behavior.
- [x] Add pointer resize behavior.
- [x] Persist block title, position, and size.
- [x] Verify state restores after app restart.

## Feasibility Evaluation

- [x] Implement desktop-overlay prototype slice.
- [x] Manually check desktop layer behavior.
- [x] Check Finder icon interaction.
- [x] Check Mission Control behavior.
- [x] Check Spaces behavior.
- [x] Check multi-monitor behavior if available.
- [x] Check full-screen app behavior.
- [x] Note required permissions or OS settings for the current overlay candidate.
- [x] Record current limitations and recommendation.
- [x] Write follow-up ADR for the stack decision.
- [x] Update `SPEC.md` and `AGENTS.md` with real commands if a stack is accepted.
