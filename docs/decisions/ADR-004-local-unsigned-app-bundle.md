# ADR-004: Build a Local Unsigned App Bundle

## Status

Accepted

## Date

2026-07-05

## Context

DeskBlocks currently runs through Swift Package Manager with `swift run DeskBlocksPrototype`. That is acceptable for development, but it does not provide a normal user relaunch path after quitting the app.

The app is private and intended only for the current user's Mac. We do not yet need distribution, notarization, App Store release, login items, or installer automation.

## Decision

Create a repeatable local packaging command that builds `dist/DeskBlocks.app` from the existing SwiftPM executable.

The local app bundle:

- is unsigned and unnotarized;
- is for private local use only;
- keeps the current executable name `DeskBlocksPrototype` inside the bundle;
- uses bundle display/name metadata `DeskBlocks`;
- does not add dependencies, installer tooling, login items, launch agents, or external services.

## Alternatives Considered

### Keep Using `swift run`

- Pros: Simple and already works.
- Cons: Poor daily-use relaunch flow after quitting.
- Rejected: We need a normal `.app` launch target for private use.

### Full Xcode Project With Signing

- Pros: Closer to production packaging and signing workflows.
- Cons: More setup, more signing decisions, and not needed for the private prototype.
- Rejected for now: local unsigned bundle is enough to validate daily use.

### Notarized Distribution Build

- Pros: Required for broader distribution.
- Cons: Requires Apple Developer signing/notarization decisions.
- Rejected for now: out of scope for a private prototype.

## Consequences

- `scripts/build-local-app.sh` becomes the packaging command for the prototype.
- The generated app bundle lives under `dist/` and is ignored by Git.
- Future signing, notarization, app icon, installer, or auto-launch behavior must be handled by a later ADR.
