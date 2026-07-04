# MVP Review Gate: 2026-07-04

## Result

PASS. The current Swift/AppKit MVP is ready to use as the baseline before expanding into folder references or magnetic placement.

## Verification

- `swift run DeskBlocksCoreChecks` passed.
- `swift build` passed.
- Manual daily-use validation passed for multiple blocks, Finder/Desktop use, full-screen behavior, Spaces, Mission Control, quit, and relaunch.
- Manual visual calibration passed with native macOS folder icons and `112x104` point tile slots.
- Future UI changes should use `tasks/ui-regression-checklist.md` before being considered complete.

## SPEC Coverage

The current MVP covers the required `SPEC.md` scope:

- Create multiple named blocks through `File > New Block...`.
- Choose initial tile count during creation.
- Add and delete tile slots after creation.
- Drag and resize blocks with whole-tile snapping.
- Prevent resize states where current tiles disappear.
- Persist title, position, size, and tile count.
- Rename and remove blocks.
- Keep tile size fixed.
- Render native macOS folder icons and readable labels.
- Preserve the rule that DeskBlocks does not own, move, copy, rename, delete, or reorganize Finder files.

## ADR-002 Alignment

The MVP remains aligned with ADR-002:

- Swift/AppKit remains the accepted MVP stack.
- `DeskBlocksCore` owns deterministic geometry, snapping, state, and invariants.
- AppKit owns windows, pointer interaction, rendering, menus, and macOS desktop behavior.
- The current desktop-overlay candidate remains `CGWindowLevelForKey(.desktopIconWindow) + 1`.
- Electron and Tauri should not be revisited unless Swift/AppKit hits a concrete blocker.

## Known Limitations

- Mission Control does not treat DeskBlocks as a normal managed window; DeskBlocks remains on the desktop while other windows move forward. This remains acceptable for the MVP.
- Multi-monitor behavior is untested because no second display is available.
- Installed `.app` launch/relaunch behavior is untested; the current prototype runs through Swift Package Manager.
- Display sleep/wake and display scaling/resolution behavior remain deferred.
- Persistence is still plain JSON for the private prototype.
- Folder references were placeholders at the MVP review point; they now have follow-up implementation through bookmark-backed storage, rendering, removal, persistence, and basic drag-and-drop.
- AppKit prototype responsibilities have been split into focused files for configuration, persistence, rendering, orchestration, and the executable entry point. Keep future folder-reference UI in this split shape instead of rebuilding a monolithic file.

## Definition Of Done

- Correctness: PASS for current MVP scope. Core checks and manual runtime validation passed.
- Quality: PASS. The AppKit prototype has been decomposed before the next feature slice.
- Integration: PASS for SwiftPM prototype flow. Packaging remains explicitly out of scope.
- Documentation: PASS. SPEC, state model, ADRs, and MVP plan describe current behavior and limits.
- Ship-readiness: PASS for private prototype use. Not ready for packaged distribution.

## Next Feature Decision

Next: implement Folder Reference Tiles before Magnetic Placement.

Reasoning:

- Magnetic placement depends on having a safe reference model first.
- Folder references must prove that DeskBlocks can store and render folder identity without moving or owning Finder files.
- ADR-003 decided bookmark-backed folder references before drag/drop magnet behavior.

Folder reference storage, rendering, removal, persistence, and basic drag-and-drop now exist. Do not implement magnetic placement until the current folder-reference behavior has been reviewed as a stable baseline.
