# AGENTS.md Best Practices

This note is the local checklist to read before editing the root `AGENTS.md`.

Primary sources:

- OpenAI Codex manual: Custom instructions with `AGENTS.md`
- OpenAI Codex manual: Agent Skills
- OpenAI Codex manual: Rules

## Purpose

`AGENTS.md` is durable project guidance for Codex. It should tell agents how to work in this repository, not duplicate specs, task plans, or full skill instructions.

Use `AGENTS.md` for:

- Stable project expectations.
- Real setup and verification commands.
- Workflow order and required gates.
- Repository boundaries and safety rules.
- Pointers to deeper docs, specs, skills, and references.

Do not use `AGENTS.md` for:

- Long product specs.
- Temporary task notes.
- Full copied skill content.
- Commands that do not exist yet.
- Historical change logs.

## Discovery Rules To Respect

- Codex reads `AGENTS.md` before doing work.
- Project guidance is discovered from the project root down to the current working directory.
- Nested `AGENTS.md` or `AGENTS.override.md` files can override broader guidance for subtrees.
- Closer files override earlier guidance because they appear later in the instruction chain.
- Keep root guidance concise so it stays below instruction-size limits.

## DeskBlocks Rules

- Treat the root `AGENTS.md` as WIP but always update it deliberately.
- Before changing `AGENTS.md`, read this file and check whether the change belongs in `AGENTS.md`, `SPEC.md`, an ADR, or a task file.
- Do not add dev/build/test commands until matching project files exist.
- Keep DeskBlocks-specific guidance separate from copied upstream Agent Skills reference material.
- Reference local skill files by path instead of copying their full content into `AGENTS.md`.
- Update `AGENTS.md` when the project gains a real app stack, command set, or durable architectural rule.

## Recommended Shape

A strong root `AGENTS.md` should stay close to this shape:

- Project snapshot.
- Working order.
- Required gates.
- Local reference routing.
- Commands and verification.
- Boundaries.
- Product constraints.

Add sections only when they are stable and useful on most future runs.

## Change Checklist

Before editing `AGENTS.md`, confirm:

- The new rule is durable, not task-specific.
- The rule is actionable for an agent.
- The rule does not duplicate a more detailed doc.
- All referenced local paths exist.
- Any listed command exists in the repository.
- The wording is concise and current-state oriented.

After editing `AGENTS.md`, verify:

- `AGENTS.md` exists at the repository root.
- Local references resolve.
- No unrelated source-project/product context was introduced.
- The file still says no commands exist unless a stack has been added.
