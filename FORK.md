# AeroSpace display-reconcile fork

Baseline: AeroSpace **0.21.3-Beta** at `d56e163`. This fork adds one behavior: after a display count or origin change, the **already-focused workspace stays visible** on a legal surviving monitor. The restore runs in shared monitor rearrange, before layout.

## Intentional limits

- Mapping of **non-focused** workspaces is unchanged.
- **Numeric monitor selectors** and force-assignment resolution are unchanged.
- No claim about frame rate, lid-close latency, or other live performance.

## Test

From this tree, with Xcode selected:

```
xcrun swift test --jobs 2
```

`DisplayReconcileTest` covers forced 3→2 focus restore, already-visible focus, unforced collision, cold focus init, same-count origin change via `activeWorkspace`, and empty-monitor skip.

## Build artifact

GitHub Actions under `.github/workflows` builds the fork. Download the workflow artifact; do not treat an unsigned or ad-hoc signed binary as the upstream release.

## Install

A binary from this fork has a **new code signature**. macOS Accessibility must be granted again (System Settings → Privacy & Security → Accessibility) or the app cannot move windows. Granting Accessibility is a user action; this document is not an install script.
