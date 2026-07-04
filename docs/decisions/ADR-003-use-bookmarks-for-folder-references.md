# ADR-003: Use Bookmarks for Folder References

## Status

Accepted

## Date

2026-07-04

## Context

DeskBlocks tiles need to refer to Finder folders without taking ownership of those folders. Moving a DeskBlocks block must move the rendered tile item visually, but must not move, copy, rename, delete, or reorganize the underlying Finder folder.

Folder references must survive app restarts and should remain robust if a folder is moved or renamed through Finder. The MVP currently runs as a Swift Package Manager AppKit prototype without sandbox packaging, but future packaging may require App Sandbox decisions.

Apple exposes bookmark data APIs on `URL` for creating and later resolving persistent file references. Apple also documents App Sandbox as a future packaging/security boundary that can affect file access.

## Decision

Persist folder references as bookmark-backed DeskBlocks state:

- `FolderReference.kind` is `bookmark`.
- `FolderReference.bookmarkDataBase64` stores the bookmark data as a JSON-safe string.
- `FolderReference.lastKnownPath` stores the last visible path as fallback/debug metadata, not as the primary identity.
- `TileReference.tileIndex` records the tile slot where the reference is rendered.

DeskBlocks will treat the bookmark as the durable folder reference and the path as secondary metadata. A tile reference belongs to DeskBlocks UI state only; it never implies ownership of the Finder folder.

## Alternatives Considered

### Plain Path String

- Pros: Simple to inspect and serialize.
- Cons: Fragile when users rename or move folders.
- Rejected: Good as fallback metadata, not durable enough as the primary reference.

### Finder Alias File

- Pros: Familiar macOS concept and robust outside the app.
- Cons: Requires creating/managing extra files and makes DeskBlocks state depend on filesystem side effects.
- Rejected: More moving parts than the MVP needs.

### Bookmark Data

- Pros: App-owned, serializable, designed for persistent file references, and compatible with future security-scoped access if packaging requires it.
- Cons: Less human-readable than a path and requires explicit resolve/error handling.
- Accepted: Best fit for private app state and future AppKit packaging.

## Consequences

- Persistence format changes from a placeholder string toward structured folder reference data.
- Legacy placeholder string references still decode as bookmark references with an empty `lastKnownPath`.
- The core model can represent sparse tile placement because a reference now carries `tileIndex`.
- Future UI work should create bookmark data when the user selects or drops a folder, then call the core placement API.
- Future sandboxed packaging must decide whether folder bookmarks should be security-scoped before shipping an installed app.

## Sources

- Apple Developer Documentation: [`URL.bookmarkData(options:includingResourceValuesForKeys:relativeTo:)`](https://developer.apple.com/documentation/foundation/url/bookmarkdata%28options%3Aincludingresourcevaluesforkeys%3Arelativeto%3A%29)
- Apple Developer Documentation: [`URL.init(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)`](https://developer.apple.com/documentation/foundation/url/init%28resolvingbookmarkdata%3Aoptions%3Arelativeto%3Abookmarkdataisstale%3A%29)
- Apple Developer Documentation: [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
