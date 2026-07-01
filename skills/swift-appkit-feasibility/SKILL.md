---
name: swift-appkit-feasibility
description: Guide Swift/AppKit feasibility work for DeskBlocks. Use when creating, changing, reviewing, or debugging a Swift/AppKit macOS prototype, especially NSWindow behavior, desktop-level overlays, transparency, dragging, resizing, whole-tile snapping, persistence, and evidence gathering before a stack decision.
---

# Swift/AppKit Feasibility

## Overview

Use this skill to test whether Swift/AppKit can satisfy DeskBlocks' macOS desktop behavior before treating it as the production stack. Optimize for evidence, small slices, and reversible decisions.

## Operating Rules

- Treat the prototype as a feasibility probe, not the MVP.
- Verify AppKit and Swift APIs against official Apple documentation or local SDK headers before relying on them.
- Keep `NSWindow` behavior, grid/tile math, and persistence separable.
- Do not add broad product features while desktop behavior is still unproven.
- Do not declare Swift/AppKit selected until the feasibility checklist and follow-up ADR support that decision.
- Record limitations as findings, not as failures to hide.

## Workflow

1. Read the current project state:
   - `SPEC.md`
   - `tasks/plan.md`
   - `tasks/todo.md`
   - relevant ADRs in `docs/decisions/`
2. Identify the exact question the slice should answer.
3. Verify required AppKit APIs from Apple sources or local SDK headers.
4. Implement the smallest runnable change.
5. Test pure logic with automated tests where practical.
6. Verify macOS behavior manually and capture notes.
7. Update the task/ADR/spec docs when evidence changes the recommendation.

## Related Skills

Combine this skill with these local reference skills only when their condition applies:

- `skills/source-driven-development/SKILL.md`: use when verifying Swift/AppKit APIs, SDK symbols, or Apple-documented behavior.
- `skills/incremental-implementation/SKILL.md`: use when implementing a prototype slice that touches more than one file.
- `skills/test-driven-development/SKILL.md`: use for grid math, snapping, persistence serialization, or behavior changes that can be automated.
- `skills/debugging-and-error-recovery/SKILL.md`: use when runtime window behavior, focus, transparency, or persistence fails unexpectedly.
- `skills/documentation-and-adrs/SKILL.md`: use when feasibility evidence changes `SPEC.md`, tasks, or architectural decisions.

## Source Verification

Prefer these sources, in order:

1. Apple Developer documentation.
2. Local macOS SDK headers, especially AppKit headers under the active SDK path from `xcrun --show-sdk-path`.
3. Existing project code and documented decisions.

When a behavior is undocumented or source evidence is incomplete, label it as empirical and prove it in the prototype before depending on it.

## Feasibility Evidence

For each prototype slice, capture the result for the relevant checks:

- Launch and quit behavior.
- Transparent or visually minimal window presentation.
- Window level relative to the desktop, Finder icons, normal app windows, full-screen apps, Spaces, and Mission Control.
- Drag behavior.
- Resize behavior.
- Whole-tile snapping behavior.
- Minimum block size.
- Persistence across restart.
- Multi-monitor behavior when available.
- Required macOS permissions or settings.
- Resource observations if they could affect stack choice.

## Test Boundary

Use automated tests for deterministic logic:

- tile size invariants
- column/row calculations
- snap up/down behavior
- minimum dimensions
- persistence serialization

Use manual verification for OS behavior that cannot be trusted from unit tests alone:

- actual window level behavior
- focus and click behavior
- Finder icon interaction
- Spaces and Mission Control
- full-screen app interaction

## Completion Bar

Before calling a Swift/AppKit feasibility slice done:

- The tested question is explicit.
- Source-backed API assumptions are documented in the response or nearby decision notes.
- Automated checks exist for pure logic when practical.
- Manual OS behavior checks are recorded.
- Any new command that genuinely exists is reflected in `AGENTS.md`; otherwise, do not invent one.
- The result either advances, constrains, or rejects Swift/AppKit as the candidate stack.
