# DeskBlocks Feasibility Evaluation - 2026-07-01

## Status

Partial. Automated and code-level checks were completed. Manual desktop behavior checks still need human visual evaluation.

## Test Run Metadata

- Date: 2026-07-01
- macOS version: 15.7.7 (Build 24G720)
- Hardware/display setup: iMac19,1, Radeon Pro 580X, 40 GB memory
- Prototype stack: Swift/AppKit via Swift Package Manager
- Prototype commands:
  - `swift build`
  - `swift run DeskBlocksCoreChecks`
  - `swift run DeskBlocksPrototype`
- Prototype commit or file snapshot: no Git repository yet
- Tester: Codex for automated checks; human visual desktop checks pending

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

This means the prototype now has code-level support for a desktop-adjacent overlay candidate, and candidate 2 passed the first desktop/Finder interaction check. It still needs evaluation in Spaces, Mission Control, full-screen apps, and any multi-monitor setup before the stack decision.

## Manual Checks Still Required

| Check | Status | Notes |
|---|---|---|
| One block is visually present in the intended desktop layer. | PASS | Candidate 2 visible on desktop. |
| Block can be moved by pointer interaction. | PASS | Candidate 2 can be dragged. |
| Block can be resized by pointer interaction. | PASS | Candidate 2 can be resized. |
| Resize snapping feels stable and visible. | PASS | User reported resize test as pass for candidate 2. |
| Finder icons remain usable around the block. | PASS | User reported candidate 2 is not too intrusive relative to Finder icons. |
| Mission Control behavior is acceptable. | BLOCKED | Needs human visual confirmation. |
| Spaces behavior is acceptable. | BLOCKED | Needs human visual confirmation. |
| Full-screen app behavior is acceptable. | BLOCKED | Needs human visual confirmation. |
| Multi-monitor behavior is acceptable, if available. | BLOCKED | Needs human visual confirmation. |

## Limitations Found

- The current window-level choice has passed the first desktop/Finder interaction check, but has not been tested in Mission Control, Spaces, full-screen apps, or multi-monitor setups.
- Spaces, Mission Control, full-screen app behavior, and multi-monitor behavior have not been proven.
- The resource observation is a single smoke sample, not a reliable performance benchmark.
- The project is not yet a Git repository, so there is no commit-based rollback point.

## Recommendation

Continue with Swift/AppKit into the remaining manual evaluation of Mission Control, Spaces, full-screen apps, and multi-monitor behavior before writing the final stack ADR.

Next human check should specifically test:

- transparent or visually lightweight window style
- candidate `NSWindow.Level`
- Spaces and Mission Control behavior
- whether the block can remain useful without disrupting normal desktop use

Do not accept Swift/AppKit as the production stack until that desktop-layer slice is manually evaluated.
