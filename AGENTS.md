# DeskBlocks Agent Guide

## Project Snapshot

DeskBlocks is a private macOS desktop app for visual desktop organization. It creates resizable desktop blocks with fixed-size icon tiles so Finder folders and labels remain readable while the block frame grows or shrinks in whole-tile steps.

Current state:

- Swift/AppKit is accepted as the MVP application stack by `docs/decisions/ADR-002-accept-swift-appkit-for-mvp.md`.
- The current implementation uses Swift/AppKit via Swift Package Manager.
- Build, run, and core geometry check commands exist for the prototype; no lint or packaging commands exist yet.
- Local skills in `skills/` are reference workflows, not installed Codex runtime skills unless this project later moves or configures them for discovery.

## Working Order

Use this lifecycle for non-trivial work:

1. Spec
2. Plan
3. Feasibility prototype
4. Build
5. Test
6. Review

Do not skip required gates. The first macOS desktop behavior risk has enough feasibility evidence to proceed with Swift/AppKit MVP work, but new desktop-level behavior still needs focused verification.

## Required Gates

- Before editing this file, read `docs/agents-md-best-practices.md` and keep the change consistent with current Codex `AGENTS.md` guidance.
- Create or update `SPEC.md` before implementation work.
- Record major technical decisions with ADRs before committing to them, especially stack changes, persistence format changes, packaging/signing decisions, or OS-level integrations.
- Use `references/definition-of-done.md` as the completion bar for every increment.
- When a real stack exists, update this file with the actual dev, build, lint, and test commands.

## Local Reference Routing

Use the local reference workflow that matches the work:

- Spec work: `skills/spec-driven-development/SKILL.md`
- Planning and task breakdown: `skills/planning-and-task-breakdown/SKILL.md`
- Feasibility and implementation slices: `skills/incremental-implementation/SKILL.md`
- Swift/AppKit feasibility work: `skills/swift-appkit-feasibility/SKILL.md`
- Behavior tests and bug guards: `skills/test-driven-development/SKILL.md`
- UI layout, controls, and accessibility: `skills/frontend-ui-engineering/SKILL.md`
- Source-verified framework decisions: `skills/source-driven-development/SKILL.md`
- Debugging desktop or runtime failures: `skills/debugging-and-error-recovery/SKILL.md`
- Documentation and ADRs: `skills/documentation-and-adrs/SKILL.md`
- Review before considering work complete: `skills/code-review-and-quality/SKILL.md`

Specialist persona references live in `agents/`; use them only as role guidance for review, testing, security, or web-performance audits.

## Commands and Verification

Current Swift/AppKit commands:

- Build: `swift build`
- Run: `swift run DeskBlocksPrototype`
- Check core geometry: `swift run DeskBlocksCoreChecks`

No lint or packaging command exists yet. No `swift test` target exists in the current Command Line Tools setup; use `swift run DeskBlocksCoreChecks` for the current grid/snapping checks. Do not invent commands such as `npm test`, `npm run build`, `swift test`, or `cargo test` unless the matching project files exist.

For documentation and planning changes, verify with targeted file searches and a final diff review. For Swift/AppKit prototype changes, run `swift build` and `swift run DeskBlocksCoreChecks` when grid/snapping logic is affected; run `swift run DeskBlocksPrototype` only when a GUI launch check is needed.

For uncritical completed documentation and planning changes, commit after verification without a separate prompt. Ask before committing behavior changes, dependency changes, architecture changes, persistence-format changes, OS integrations, or any risky/destructive operation unless the user explicitly requested the commit.

## Boundaries

Ask before:

- Changing the app stack or architecture.
- Adding dependencies.
- Introducing external services.
- Changing persistence format.
- Creating automation, login items, accessibility permissions, or OS-level integrations.

Never:

- Copy unrelated source-project product docs, discovery material, memory-bank files, or project-specific agents into DeskBlocks.
- Treat upstream copied reference material as product requirements.
- Remove or rewrite source attribution files for copied Agent Skills material.
- Commit secrets, personal data, or generated credentials.

## Product Constraints

- Fixed tile size is a core product invariant.
- Resizing changes the block frame and visible tile count, not tile scale.
- Blocks must remain visually useful as desktop organization aids, not become a broad dashboard or window manager.
- The MVP should prove the desktop-block interaction model before adding broad customization.
