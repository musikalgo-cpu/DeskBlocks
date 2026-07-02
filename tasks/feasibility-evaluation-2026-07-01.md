# DeskBlocks Feasibility Evaluation - 2026-07-01

## Status

Complete for the current stack-feasibility decision. Automated, code-level, and primary manual desktop behavior checks were completed. Display sleep/wake and display scaling/resolution behavior are intentionally deferred because they are not required before the stack ADR.

## Test Run Metadata

- Date: 2026-07-01
- macOS version: 15.7.7 (Build 24G720)
- Hardware/display setup: iMac19,1, Radeon Pro 580X, 40 GB memory
- Prototype stack: Swift/AppKit via Swift Package Manager
- Prototype commands:
  - `swift build`
  - `swift run DeskBlocksCoreChecks`
  - `swift run DeskBlocksPrototype`
- Prototype commit or file snapshot: `07e56d2 Document overlay feasibility checkpoint` plus current working-tree manual-check notes
- Tester: Codex for automated checks; human visual desktop checks by user

## Automated Evidence

| Check | Status | Notes |
|---|---|---|
| Build succeeds. | PASS | `swift build` completed successfully. |
| Core geometry checks pass. | PASS | `swift run DeskBlocksCoreChecks` completed successfully. |
| Prototype launches. | PASS | `swift run DeskBlocksPrototype` launched without crash twice. |
| State file exists. | PASS | JSON state written to `~/Library/Application Support/DeskBlocks/prototype-state.json`. |
| State includes future tile-reference field. | PASS | JSON contains `tileReferences: []`. |
| State reload path exercised. | PASS | Second launch loaded existing JSON without crash. |
| Desktop-overlay candidate builds. | PASS | Prototype now configures a transparent/lightweight AppKit window with an explicit desktop-adjacent window level. |
| Desktop-overlay candidate launches. | PASS | `swift run DeskBlocksPrototype` launched after overlay changes without crash. |
| Idle resource observation. | PASS | Latest sampled process reading showed `0.0%` CPU and about `33 MB` RSS. This is only a smoke observation, not a benchmark. |
| Overlay candidate 1 interaction. | FAIL | `CGWindowLevelForKey(.desktopIconWindow) - 1` was visible but could not be selected, dragged, or resized. Likely below Finder desktop icon interaction. |
| Overlay candidate 2 interaction. | PASS | `CGWindowLevelForKey(.desktopIconWindow) + 1` is visible, selectable, draggable, resizable, and not too intrusive relative to Finder icons in the user's manual check. |

## Current Prototype State

The current AppKit prototype now has a first desktop-overlay candidate configuration:

- `NSApplication` uses `.regular` activation policy.
- The window uses `.titled`, `.closable`, `.resizable`, and `.fullSizeContentView`.
- The title is hidden and the titlebar is transparent.
- The window background is clear, non-opaque, and shadowless.
- The window can be dragged by its background.
- The first candidate window level was `CGWindowLevelForKey(.desktopIconWindow) - 1`; it was visible but not selectable.
- The current candidate window level is `CGWindowLevelForKey(.desktopIconWindow) + 1`, represented as `NSWindow.Level`.
- The window collection behavior is `.canJoinAllSpaces`, `.stationary`, `.ignoresCycle`, and `.fullScreenAuxiliary`.

This means the prototype now has code-level support for a desktop-adjacent overlay candidate, and candidate 2 passed the first desktop/Finder interaction check. It has also passed the first Spaces and full-screen app checks. Mission Control behavior is acceptable with a documented limitation: DeskBlocks does not enter Mission Control as a normal managed window and remains on the desktop while other windows move forward.

## Manual Checks Still Required

| Check | Status | Notes |
|---|---|---|
| One block is visually present in the intended desktop layer. | PASS | Candidate 2 visible on desktop. |
| Block can be moved by pointer interaction. | PASS | Candidate 2 can be dragged. |
| Block can be resized by pointer interaction. | PASS | Candidate 2 can be resized. |
| Resize snapping feels stable and visible. | PASS | User reported resize test as pass for candidate 2. |
| Finder icons remain usable around the block. | PASS | User reported candidate 2 is not too intrusive relative to Finder icons. |
| Mission Control behavior is acceptable. | PASS | DeskBlocks does not enter Mission Control; other windows move forward and DeskBlocks remains on the desktop. Acceptable for feasibility, but this limitation must be kept in the stack ADR. |
| Spaces behavior is acceptable. | PASS | User reported Desktop/Spaces switching as pass. |
| Full-screen app behavior is acceptable. | PASS | User reported behavior while another app is full-screen as pass. |
| Multi-monitor behavior is acceptable, if available. | N/A | No second monitor is available in the current test setup. |

## Limitations Found

- Mission Control does not treat DeskBlocks as a normal managed window. This appears acceptable for the product direction, but must be documented as a stack-decision limitation.
- Multi-monitor behavior has not been tested because no second monitor is available.
- Display sleep/wake and display scaling/resolution behavior were not tested and are intentionally deferred beyond the stack ADR.
- The resource observation is a single smoke sample, not a reliable performance benchmark.

## Recommendation

Continue with Swift/AppKit into the stack-decision ADR.

Next human check should specifically test:

- no additional manual check is required before the stack ADR

Swift/AppKit is acceptable for the MVP stack only if the Mission Control limitation is explicitly carried into the stack ADR.
