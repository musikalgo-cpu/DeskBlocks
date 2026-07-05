# DeskBlocks Token Usage Guidelines

## Purpose

Reduce token usage without lowering implementation quality. The project should keep its existing engineering gates, but avoid carrying unnecessary history, oversized context, and repeated explanation through every turn.

## Default Working Rules

- Start a new Codex thread after a completed feature slice, long debug session, or major review. Use a short handoff instead of relying on the full prior conversation.
- Keep user prompts outcome-first: goal, scope, acceptance criteria, and whether commit or app launch is wanted.
- Prefer `rg` and targeted file excerpts before reading whole files.
- Use patches for edits and concise summaries for responses; do not output whole files unless explicitly needed.
- Use only the relevant local skill or reference file for the task. Do not preload several skills defensively.
- Keep interim updates to one short sentence unless a decision or blocker needs more context.
- Commit only complete feature slices or bugfixes, not every small correction.

## Documentation Gates

- Update `SPEC.md` only when product behavior, scope, or acceptance criteria changes.
- Write an ADR only for persistence format, architecture, OS integration, dependency, packaging/signing, or other decisions that are expensive to reverse.
- Keep detailed checklists, commands, and evidence in `tasks/` or `docs/`; keep `AGENTS.md` concise and durable.

## Verification Budget

- Documentation-only changes: targeted file search and diff review.
- UI-only Swift/AppKit changes: `swift build` first.
- Core, grid, snapping, state, or persistence changes: `swift build` plus `swift run DeskBlocksCoreChecks`.
- Manual GUI changes: build the app bundle and launch only when the user needs to test the GUI behavior.
- Avoid rebuilding and relaunching after every micro-change unless the active bug requires exactly that feedback loop.

## Handoff Format

Use this compact handoff when starting a new thread:

```markdown
# DeskBlocks Handoff

Current goal:
- ...

Current state:
- Branch/commit:
- Dirty files:
- Last verified commands:

Important decisions:
- ...

Next step:
- ...

Known risks/blockers:
- ...
```

## What Not To Optimize Away

- Do not skip required tests for risky changes.
- Do not skip `SPEC.md` or ADR updates when the project rules require them.
- Do not hide uncertainties to save tokens; ask concise questions when product intent is genuinely ambiguous.
- Do not make `AGENTS.md` a changelog or task log.
