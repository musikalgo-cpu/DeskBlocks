# DeskBlocks Project Registry

## Purpose

Use this file after `AGENTS.md` to find the smallest useful context for a task. It is a navigation map, not a full code index. Prefer targeted `rg` searches and small file excerpts after selecting the likely area.

## First Read

- Always start with `AGENTS.md`.
- Use this registry next for repository navigation.
- Read `SPEC.md` only when product behavior, scope, or acceptance criteria may change.
- Read ADRs only when the task touches the decision they record.

## Code Areas

| Area | Read first when working on |
|---|---|
| `Sources/DeskBlocksCore/TileGridMetrics.swift` | Block state, tile grid math, snapping, persistence-safe models, folder-reference invariants. |
| `Sources/DeskBlocksCoreChecks/main.swift` | Core executable checks for grid, state, persistence, and smoke-guarded invariants. |
| `Sources/DeskBlocksPrototype/AppDelegate.swift` | App lifecycle, menus, windows, dialogs, persistence orchestration, folder picker, open/remove actions. |
| `Sources/DeskBlocksPrototype/DeskBlockView.swift` | Rendering, context menus, mouse handling, drag/drop target behavior, tile labels/icons, overflow indicators. |
| `Sources/DeskBlocksPrototype/AppConfiguration.swift` | AppKit/Core conversion helpers, overlay window configuration, prototype geometry constants. |
| `Sources/DeskBlocksPrototype/PrototypeStateStore.swift` | JSON load/save path and persistence fallback behavior. |
| `scripts/build-local-app.sh` and `packaging/Info.plist` | Local unsigned `.app` bundle creation and app metadata. |

## Task Routing

| Task | Read first | Usually verify with |
|---|---|---|
| Resize, snapping, viewport, tile count | `TileGridMetrics.swift`, then `DeskBlocksCoreChecks/main.swift` | `swift build`; `swift run DeskBlocksCoreChecks` |
| Persisted block state or JSON compatibility | `TileGridMetrics.swift`, `PrototypeStateStore.swift` | `swift build`; `swift run DeskBlocksCoreChecks`; relevant smoke command |
| Window level, move, resize, lock, close behavior | `AppDelegate.swift`, then `AppConfiguration.swift` | `swift build`; GUI launch if behavior needs manual confirmation |
| Rendering, folder icon look, title, chevrons, transparent hit areas | `DeskBlockView.swift` | `swift build`; app bundle only for manual visual test |
| Context menu actions | `DeskBlockView.swift`, `AppDelegate.swift` | `swift build`; GUI launch if menu behavior needs manual confirmation |
| Folder picker, bookmark references, open/remove folder | `AppDelegate.swift`, `TileGridMetrics.swift` | `swift build`; `swift run DeskBlocksCoreChecks`; folder smoke if relevant |
| Packaging or relaunch path | `scripts/build-local-app.sh`, `packaging/Info.plist`, ADR-004 | `scripts/build-local-app.sh`; verify `dist/DeskBlocks.app` exists |
| Product behavior change | `SPEC.md`, then relevant code area | Match verification to affected code |
| Persistence, architecture, OS integration, dependency, packaging/signing decision | relevant ADRs in `docs/decisions/` | Diffs plus affected build/check commands |

## Documentation Routing

| Document | Use for |
|---|---|
| `SPEC.md` | Product source of truth and acceptance-level behavior. |
| `docs/models/deskblocks-state-model.md` | State invariants, lifecycle model, impossible states. |
| `docs/decisions/ADR-002-accept-swift-appkit-for-mvp.md` | Swift/AppKit stack decision. |
| `docs/decisions/ADR-003-use-bookmarks-for-folder-references.md` | Folder reference persistence. |
| `docs/decisions/ADR-004-local-unsigned-app-bundle.md` | Local `.app` packaging. |
| `docs/decisions/ADR-005-persist-block-title-colors.md` | Title color persistence. |
| `docs/decisions/ADR-006-persist-block-display-and-lock-options.md` | Empty tile visibility and block lock persistence. |
| `docs/token-usage-guidelines.md` | Context, handoff, and verification-budget rules. |
| `tasks/ui-regression-checklist.md` | Manual AppKit/UI regression checks. |

## Avoid Reading First

- `README.agent-skills.md`: upstream reference material, not DeskBlocks product guidance.
- Long historical task files in `tasks/`: read only when the current task explicitly depends on past evidence.
- All ADRs at once: read the ADR that matches the decision area.
- Full Swift files by default: use `rg` and targeted ranges unless the whole file is directly affected.
