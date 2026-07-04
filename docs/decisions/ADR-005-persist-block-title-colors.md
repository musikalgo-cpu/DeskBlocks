# ADR-005: Persist Block Title Colors as App-Owned RGBA State

## Status

Accepted

## Date

2026-07-05

## Context

DeskBlocks currently renders block titles in pure white. The next MVP customization step is allowing the user to change a block title color through a native macOS color picker and keep that choice across app relaunches.

This is a persistence-format change because the chosen color becomes part of durable block state. The core model should remain deterministic and AppKit-independent so geometry, normalization, and JSON round-trip checks stay in `DeskBlocksCore`.

## Decision

Persist block title color inside `DeskBlockState` as an app-owned RGBA value:

- `DeskBlockState.titleColor` stores the durable title color.
- `BlockColor` is a small Codable core type with normalized `red`, `green`, `blue`, and `alpha` components.
- Legacy saved state that does not contain `titleColor` decodes to pure white.
- AppKit converts between `NSColor` and `BlockColor` at the UI boundary.

DeskBlocks treats title color as visual app state only. It does not derive from Finder metadata, system accent color, or theme automation.

## Alternatives Considered

### Keep Title Color Ephemeral

- Pros: No persistence migration.
- Cons: User customization disappears after quit/relaunch.
- Rejected: Poor fit for a desktop organization tool that already persists block state.

### Persist AppKit-Specific Color Archives

- Pros: Can preserve AppKit color objects directly.
- Cons: Couples core persistence to AppKit types and archive formats.
- Rejected: Core state should stay simple, deterministic, and cross-layer portable.

### Global Single Title Color

- Pros: Simpler settings surface.
- Cons: Prevents per-block customization and is harder to evolve later if blocks need independent emphasis.
- Rejected: Per-block state matches the existing block-owned persistence model better.

## Consequences

- Saved JSON format grows by one optional field per block.
- Older state files remain compatible through default decoding.
- Title color changes can be verified in core serialization checks without launching the UI.
- AppKit owns the native `NSColorPanel` interaction, but the stored value remains a plain core model type.
