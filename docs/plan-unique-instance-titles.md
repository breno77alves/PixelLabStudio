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

- [ ] Add tests for title formatting and lock lifecycle.
- [ ] Confirm the tests fail before the manager exists.

### Phase 2: Implementation

- [ ] Implement atomic claim, stale recovery, ownership validation, and release.
- [ ] Integrate claim/title/release into the main scene lifecycle.

### Checkpoint

- [ ] New tests pass.
- [ ] Existing hotkey, responsive-layout, and scene-template tests pass.

### Phase 3: Windows verification

- [ ] Export a separate test package.
- [ ] Launch multiple instances and confirm distinct logged/native titles.
- [ ] Review correctness, readability, architecture, security, and performance.
- [ ] Commit, package, and push only the isolated feature branch.

## Risks and Mitigations

- Simultaneous startup: atomic directory rename decides the winner.
- Crash between temporary lock creation and claim: PID-named candidates are
  cleaned on the next startup when their owner is no longer alive.
- PID reuse: lock ownership is checked again before release; active processes
  are never reclaimed.
