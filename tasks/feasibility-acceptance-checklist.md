# DeskBlocks Feasibility Acceptance Checklist

## Purpose

Use this checklist to decide whether the Swift/AppKit feasibility prototype proves enough macOS desktop behavior to justify continued MVP work.

This checklist is evidence for:

- `SPEC.md` feasibility success criteria.
- `docs/decisions/ADR-001-tech-stack-feasibility.md`.
- The later stack-decision ADR.

## Test Run Metadata

- Date:
- macOS version:
- Hardware/display setup:
- Prototype stack:
- Prototype command:
- Prototype commit or file snapshot:
- Tester:

## Status Key

- `PASS`: Works acceptably for the feasibility goal.
- `FAIL`: Does not work, or behavior conflicts with DeskBlocks requirements.
- `BLOCKED`: Could not be tested; explain why.
- `N/A`: Not applicable to the current machine or prototype.

## Gate 0: Scope Control

The prototype must stay focused on feasibility.

| Check | Status | Notes |
|---|---|---|
| Prototype contains one hard-coded block, not a full MVP. |  |  |
| Prototype does not move, copy, delete, rename, or sync Finder files. |  |  |
| Prototype does not require unapproved OS permissions or external services. |  |  |
| Grid/tile logic is separable from macOS window behavior. |  |  |
| Any real dev/build/test commands are documented in `SPEC.md` and `AGENTS.md`. |  |  |

## Launch And Quit

| Check | Status | Notes |
|---|---|---|
| App launches without crash. |  |  |
| One DeskBlocks block appears after launch. |  |  |
| App can be quit normally. |  |  |
| Relaunch does not create duplicate stale blocks. |  |  |
| Startup time feels acceptable for a private desktop utility. |  |  |

## Desktop Presentation

| Check | Status | Notes |
|---|---|---|
| Block appears in a desktop-appropriate macOS layer. |  |  |
| Block is visually lightweight enough for normal desktop use. |  |  |
| Window chrome, border, title, and background match the feasibility goal. |  |  |
| Transparency or visual minimalism does not make the block unreadable. |  |  |
| Block position is not unexpectedly changed by macOS after launch. |  |  |

## Finder And Normal Desktop Use

| Check | Status | Notes |
|---|---|---|
| Finder icons remain visible enough to judge DeskBlocks' intended use. |  |  |
| Finder labels remain readable near or inside the block area. |  |  |
| Normal desktop clicking is not made unacceptably difficult. |  |  |
| Normal Finder interaction outside the block remains usable. |  |  |
| Any unavoidable Finder interaction limitation is documented clearly. |  |  |

## Drag Behavior

| Check | Status | Notes |
|---|---|---|
| Block can be moved with pointer interaction. |  |  |
| Dragging feels stable and does not jump unexpectedly. |  |  |
| Dragging does not accidentally resize the block. |  |  |
| Dragging works after app launch and after relaunch. |  |  |
| Final position can be recorded for persistence testing. |  |  |

## Resize Behavior

| Check | Status | Notes |
|---|---|---|
| Block can be resized with pointer interaction. |  |  |
| Resize affordance is discoverable enough for a feasibility prototype. |  |  |
| Resize operation feels stable and does not jump unexpectedly. |  |  |
| Block cannot be resized below the minimum usable size. |  |  |
| Resize does not accidentally move the block in an unacceptable way. |  |  |

## Tile Geometry And Snapping

Record prototype tile dimensions before testing:

- Tile width:
- Tile height:
- Minimum columns:
- Minimum rows:
- Title/chrome allowance:

| Check | Status | Notes |
|---|---|---|
| Tile size remains constant during resize. |  |  |
| Width snaps to whole tile columns. |  |  |
| Height snaps to whole tile rows. |  |  |
| Resize up increases columns/rows predictably. |  |  |
| Resize down removes only whole columns/rows. |  |  |
| No half-tile final state is possible. |  |  |
| Minimum size is at least one usable tile plus title/frame allowance. |  |  |
| Tile dimensions appear plausible for Finder folder icon and label readability. |  |  |

## Persistence

| Check | Status | Notes |
|---|---|---|
| Block title persists after quit and relaunch. |  |  |
| Block position persists after quit and relaunch. |  |  |
| Block size persists after quit and relaunch. |  |  |
| Restored size remains snapped to whole tile rows and columns. |  |  |
| Persistence failure mode is understandable and non-destructive. |  |  |

## macOS Edge Areas

| Check | Status | Notes |
|---|---|---|
| Behavior with Mission Control is acceptable or limitation is documented. |  |  |
| Behavior across Spaces is acceptable or limitation is documented. |  |  |
| Behavior while another app is full-screen is acceptable or limitation is documented. |  |  |
| Multi-monitor behavior is acceptable, if a second display is available. |  |  |
| Behavior after display sleep/wake is acceptable or limitation is documented. |  |  |
| Behavior after changing display scaling/resolution is acceptable or limitation is documented. |  |  |

## Permissions And System Settings

| Check | Status | Notes |
|---|---|---|
| Required permissions, if any, are identified. |  |  |
| App works without Accessibility permission, or the need is justified. |  |  |
| App works without Screen Recording permission, or the need is justified. |  |  |
| App works without login item setup. |  |  |
| No unapproved automation or OS integration is introduced. |  |  |

## Resource Observations

This is not a benchmark. Capture only obvious concerns that could affect the stack decision.

| Check | Status | Notes |
|---|---|---|
| Idle CPU use appears acceptable. |  |  |
| Memory use appears acceptable for a private desktop utility. |  |  |
| Prototype does not create obvious energy or responsiveness issues. |  |  |

## Decision Summary

### Must Pass For Swift/AppKit To Continue

- One block displays in an acceptable desktop-appropriate layer.
- Drag works.
- Resize works.
- Resize snaps to whole tile rows and columns.
- Tile size remains constant.
- Title, position, and size persist after restart.
- Normal desktop/Finder use is not made unacceptably difficult.
- Required permissions and limitations are understood.

### Result

- Recommendation: Continue with Swift/AppKit / test another stack / stop and redesign
- Blocking failures:
- Non-blocking limitations:
- Follow-up tasks:
- ADR update needed: Yes / No

