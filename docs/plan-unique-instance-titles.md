# Implementation Plan: Unique Instance Titles

## Architecture Decisions

- Use one small manager object instead of putting filesystem coordination
  directly in `main.gd`.
- Prepare a PID-owned candidate directory and atomically rename it to the
  lowest free numbered slot. This avoids two processes both believing they
  created the same lock.
- Keep already-running titles stable; only newly opened processes reuse freed
  numbers.
- Fall back to the process ID if all numbered slots are unavailable or the
  user-data directory cannot be written.

## Tasks

### Phase 1: Contract and tests

- [x] Add tests for title formatting and lock lifecycle.
- [x] Confirm the tests fail before the manager exists.

### Phase 2: Implementation

- [x] Implement atomic claim, stale recovery, ownership validation, and release.
- [x] Integrate claim/title/release into the main scene lifecycle.

### Checkpoint

- [x] New tests pass.
- [x] Existing hotkey, responsive-layout, and scene-template tests pass.

### Phase 3: Windows verification

- [x] Export a separate test package.
- [x] Launch multiple instances and confirm distinct logged/native titles.
- [x] Review correctness, readability, architecture, security, and performance.
- [x] Commit, package, and push only the isolated feature branch.

## Risks and Mitigations

- Simultaneous startup: atomic directory rename decides the winner.
- Crash between temporary lock creation and claim: old candidates are probed
  and cleaned on the next startup.
- Process visibility: each owner keeps its file handle open for its lifetime,
  so correctness does not depend on sibling-process visibility.
