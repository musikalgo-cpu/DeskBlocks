# ADR-007: Persist Folder Reference Notes

## Status

Accepted

## Date

2026-07-05

## Context

DeskBlocks folder tiles need an optional user-written description. The note should survive app relaunch, appear only when the user added text, and remain part of DeskBlocks' reference model rather than the real Finder folder.

## Decision

Persist an optional `note` string on each `TileReference`.

Legacy tile references without the field decode with `note = nil`. Empty or whitespace-only note edits are normalized to `nil`, which hides the tile's info indicator.

Notes belong to the current folder reference. Removing or replacing a folder reference removes its note because the replacement creates a new `TileReference`.

DeskBlocks does not write notes into Finder comments, extended attributes, sidecar files, or the underlying folder.

## Alternatives Considered

### Store Notes by Tile Index

- Pros: A note could survive removing a folder from a tile.
- Cons: It can attach old context to a different future folder.
- Rejected: The note describes the current folder reference, not the slot.

### Store Notes in Finder Metadata

- Pros: Notes could follow the folder outside DeskBlocks.
- Cons: It violates the app-owned reference model and mutates user folders.
- Rejected: DeskBlocks must not modify Finder folders for MVP tile metadata.

## Consequences

- Saved JSON grows by one optional field per noted tile reference.
- Existing saved state remains compatible through default decoding.
- UI must show note affordances only for occupied folder tiles with non-empty notes.
