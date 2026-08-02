# FCPCommandConsole status

Captured 2026-08-02 (local machine, core implementation audit).

## Complete in this stage

- Local Git repository initialized at `/Users/marcboyer/Developer/FCPCommandConsole`.
- Eight runtime directories created at `/Users/marcboyer/Movies/FCPCommandConsole/`:
  `previews`, `renders`, `overlays`, `depth-maps`, `logs`, `jobs`, `provenance`,
  and `usage`.
- Six focused repositories cloned shallowly below `reference/`; exact HEADs,
  source URLs, and observed licenses are locked in `docs/REFERENCE_LOCK.json`.
- Machine inventory and a bounded SpliceKit compatibility assessment are in
  `docs/MACHINE_REPORT.md`.
- Focused repository integration/deferment notes are in
  `docs/REPOSITORY_AUDIT.md`.
- Typed four-effect registry/planner/validator, policy foundations, CLI, and
  deterministic overlay adapter are implemented under `service/`, `registry/`,
  `schemas/`, and `Sources/`.
- The fixed Phase 1 identifiers are `native.targeted_rotate_zoom`,
  `look.old_television`, `transition.natural_dissolve`, and
  `motion.living_still`.

## Evidence classes

| Area | State | Evidence boundary |
| --- | --- | --- |
| Source/repository | complete | This commit, clean Git worktree, no remote configured |
| Runtime directories | complete | Directory listing under `~/Movies/FCPCommandConsole` |
| Reference snapshots | complete | Six shallow clones and `REFERENCE_LOCK.json` |
| Machine inventory | observed | Command output recorded in `docs/MACHINE_REPORT.md` |
| Final Cut Pro integration | not proven | No patcher, injected copy, bridge, library, or project was used |
| ComfyUI/DepthFlow installation | not proven | Source inspection only; no dependencies/models were installed |
| Media render/export | not proven | No input media was uploaded, processed, or rendered |
| Core planner/policy behavior | tested | `swift test`, `make test` |
| Generated overlay artifact | locally verified | FFmpeg + ffprobe metadata/SHA-256; no FCP insertion |
| Product behavior | bounded only | Native FCP runtime remains unproven |

The next architecture stage must convert these observations into explicit,
reversible tests. It must not treat source claims, a compatible version label, or
the presence of `ffmpeg` as installed/live proof.
