# ADR-006: Persist Block Display and Lock Options

## Status

Accepted

## Date

2026-07-05

## Context

DeskBlocks blocks now need two small per-block options:

- hide empty tile placeholders so only occupied folder tiles are visually prominent;
- lock a block's position and size so an arranged block is not moved or resized accidentally.

Both options affect daily-use behavior and should survive relaunch. They are AppKit-facing features, but the durable truth belongs in `DeskBlockState` so load, save, and normalization remain deterministic.

## Decision

Persist two boolean flags on each `DeskBlockState`:

- `hidesEmptyTiles` controls whether empty tile placeholders are drawn.
- `isLocked` controls whether the AppKit window can be moved or resized.

Legacy state that does not contain either field decodes as:

- `hidesEmptyTiles = false`
- `isLocked = false`

Hiding empty tiles is visual only. Empty tile slots still exist as valid placement targets, and folder references keep their tile indexes.

Locking a block freezes its position and size. It does not prevent opening, replacing, or removing folder references, but tile add/delete operations are disabled while locked because they can change the block's required size.

Known MVP limitation: because the block window is optically transparent, right-clicking a fully transparent empty area in a locked block can open the macOS Desktop context menu instead of the DeskBlocks context menu. Unlock remains available from an occupied folder tile or the app menu. Further transparent-hit-testing experiments are deferred out of this slice.

## Alternatives Considered

### Global Settings

- Pros: Simpler persistence.
- Cons: Too coarse; different blocks may need different visual density or lock state.
- Rejected: Per-block options match the existing block-owned state model.

### Hide Empty Tiles by Shrinking Tile Count

- Pros: Fewer visible gaps.
- Cons: Changes the user's tile layout and can shift folder positions.
- Rejected: Visibility must not change tile identity or placement.

### Lock Only AppKit Window Chrome

- Pros: Minimal code.
- Cons: Persisted state could still drift if move/resize callbacks fire.
- Rejected: The core lock flag should be enforced both in window interaction and state updates.

## Consequences

- Saved JSON format grows by two optional boolean fields per block.
- Older state remains compatible through default decoding.
- UI rendering must respect `hidesEmptyTiles` without changing hit-testing or tile placement.
- AppKit move/resize handling must respect `isLocked` and restore the stored frame if a locked window is moved by an external/system path.
- The MVP accepts the transparent-area context menu limitation while preserving optical transparency.
