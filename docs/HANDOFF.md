# FCPCommandConsole Handoff (for Claude)

Date: 2026-08-03

Goal: private local-first Final Cut command assistant.
Current objective: finish Phase 1 after current blocker is resolved.

## 0) Current checkpoint

- Repository: `/Users/marcboyer/Developer/FCPCommandConsole`
- Branch: `standalone-app`
- HEAD: `c282b0f` (`Anchor local package writes and invalidate stale plans`)
- Worktree: clean
- Build/test evidence at this checkpoint: `swift build` passed;
  `swift test` passed **94 tests, 0 failures**; `make test` core audit passed.
- App bundle: `/Users/marcboyer/Applications/FCPCommandConsole.app`
  (reinstalled from the working tree, `codesign --verify --deep --strict`
  passed, bundle ID and bundled schema/registry resources verified)
- Runtime root: `/Users/marcboyer/Movies/FCPCommandConsole`
- Installed bundle bundle ID: `com.marcboyer.FCPCommandConsole`

## 1) What is done right now

1. Standalone app shell and local-planner UI are implemented.
2. Schema + planner is now Schema `2.0` only for production-like pathways.
3. Final Cut claim semantics are gated and contract-driven.
4. Local-only selection is prevented from becoming a false Final Cut edit claim.
5. Inert local package builder and manifest/provenance generation are implemented.
6. Installer/launch flow exists for local app execution.
7. Local filesystem writes (package building and app install) are anchored and
   symlink-hardened; see section 4b.
8. Tests currently pass at 94 (82 at the `17e5180` checkpoint, plus 12 added by
   the section 4b pass).

Important: this means we have a hardened local tool, not yet Full Phase 1 Final Cut approval.

## 2) Exact commit history worth remembering

- `c282b0f` Anchor local package writes and invalidate stale plans
- `17e5180` Harden Final Cut selection and job validation
- `d69a0f3` Refresh standalone checkpoint documentation
- `406edb8` Add inert local plan packaging
- `184f003` Add local media planning app shell
- `98d1340` Scope FCPXML capability evidence by effect
- `51209bb` Migrate effect plans to schema v2
- `56cf92c` Reduce FCPXML probe after importer crash
- `96bc693` Add FCPXML round-trip evidence gate
- `353a7a2` Pivot to standalone handoff workflow

## 3) Architecture map you can continue from

Primary components:

- `Sources/FCPCommandConsoleApp/FCPCommandConsoleApp.swift`:
  panel and UI orchestration.
- `service/Planner.swift`:
  plan-building entry and selection token handoff.
- `service/Models.swift`:
  schema-v2 typed models, representation gating, plan validation helpers.
- `service/CapabilityGate.swift`:
  final capability decision engine.
- `service/JobCoordinator.swift`:
  validates plans before preview/package/apply.
- `service/LocalMediaAdmission.swift`:
  safe local media intake and metadata extraction.
- `service/LocalMediaSelection.swift`:
  typed slot roles and selection model.
- `service/LocalPlanPackage.swift`:
  local package builder (media + metadata).
- `service/LocalMediaOperationGeneration.swift`:
  stale-result cancellation protections.
- `service/FCPXMLRoundTripSpike.swift`:
  reduced FCPXML probe assets (not production execution path).
- `service/DirectoryDescriptor.swift`:
  `DirectoryHandle` / `SourceFileHandle`, the `*at`-syscall filesystem layer
  every package write goes through.
- `Scripts/install-app`:
  local signed install + verified backup swap.

## 4) What was fixed in latest pass (`17e5180`)

1. Removed brittle timeline magic-string checks from selection proof.
2. Made FCP-like proof use explicit verified evidence type flow.
3. Enforced schema/representation validation in job coordinator (validator can no longer be silently skipped).
4. Strengthened local/token provenance checks around identity, timeline metadata, spine flags, and adjacency.
5. Preserved backward-safe source/schema mapping for Schema v2.

Net effect: local-only artifacts and inert package generation remain possible, but they cannot claim Final Cut capability without explicit evidence.

## 4b) What was fixed in `c282b0f`

This pass closed items 1–4 of the old section 6 list. It is local-filesystem
and UI-state work only. **It produces no new Final Cut evidence and changes no
capability decision.**

1. **Descriptor-anchored package writes** (`service/DirectoryDescriptor.swift`,
   `service/LocalPlanPackage.swift`). The output root is still validated by
   path, but it is then opened with `O_DIRECTORY|O_NOFOLLOW` and every
   subsequent create, copy, hash, and publish is an `*at` syscall relative to
   that descriptor. Renaming an ancestor or swapping it for a symlink after
   validation can no longer redirect a write out of the vetted directory.
   Source media is held open by one descriptor for hash-before, copy, and
   hash-after, so those three steps provably describe one inode.
2. **Publish is exclusive and atomic.** `renameatx_np(..., RENAME_EXCL)`
   replaced the `fileExists` check plus `moveItem`, so "must not overwrite" is
   part of the rename. A dangling symlink at the operation target is now
   refused instead of being written through.
3. **Cancellation linearization.** The rename is the single commit point.
   Cancellation is no longer swallowed into `.ioFailure`, a returned package is
   never downgraded to "cancelled" (it is on disk either way), only one package
   operation may be in flight, and a cancel that loses the race is reported
   with the published path instead of being dropped.
4. **Stale-input invalidation.** `LocalMediaPlanInputs` records the command,
   target, and all three role identities a plan was built from.
   `LocalMediaPlanningResult.staleness(against:)` reports the first drift in a
   fixed order; the app drops a drifted plan, and
   `LocalPlanPackageBuilder.build(_:currentInputs:)` refuses to package one.
   This catches what re-hashing cannot: a retyped command, a moved target
   point, or a newly filled role slot leaves every hash intact.
5. **Installer hardening** (`Scripts/install-app`). Refuses a symlinked
   `~/Applications`, a symlinked or dangling `FCPCommandConsole.app` target
   (previously a dangling link was written straight through), a non-directory
   target, and a symlinked `Contents/Info.plist`. Confirms staging stayed
   inside the parent, and verifies the installed bundle (identity, resources,
   `codesign --verify --deep --strict`) after the swap, rolling back to the
   backup if verification fails.

Known limitation: replacing an installed bundle is still two renames in one
directory, not one atomic exchange — POSIX has no shell-reachable way to swap
two non-empty directories. The window between them is a rollback point, and
the result is verified, but it is not a single atomic operation.

## 5) Known high-value blocker (must clear before saying Phase 1 is done)

There is still a one-pass manual roundtrip importer blocker in Final Cut.

Immutable reduced v2 spike package:

`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/CA7D0733-A435-498E-BD82-149CFF863FC3`

Includes:

- `FCPCommandConsole-RoundTrip-Spike.fcpxml`
- `manifest.json`
- `evidence.json`
- `provenance.json`
- `plan.json`
- `README.md`
- `Media/`
- `Returned/` folder

Known crash history to preserve:

- crash report `/Users/marcboyer/Library/Logs/DiagnosticReports/Final Cut Pro-2026-08-03-082455.ips`
- incident id `42DFFCF1-9E45-41DA-992F-ADB212422B07`
- FCP version/build: 12.3 / 450152

Manual rule for the next agent:

- Perform exactly one manual import/export sanity pass with that package.
- Stop at first crash, alert, missing transition, missing media, or export mismatch.
- Record results before any mutation/retry.
- Only admit contracts that match observed behavior.

## 6) Remaining technical work before all four workflows can be claimed

Items 1–4 of this list are done in the working tree; see section 4b. What is
left is the part that cannot be done in code:

1. One successful import/export roundtrip for minimal contract (dissolve pathway only), then build other contracts only with manual evidence.
2. Workflow validations:
   - targeted rotate/zoom keyframe editability
   - natural dissolve manual duration/edge edits
   - old TV overlays/controls are native-editable in Final Cut
   - living still movement/fade/color editability

## 7) Evidence and safety constraints to preserve

1. Never edit source media.
2. Never use stock Final Cut app or production libraries.
3. Never use AppleScript, Accessibility, keyboard/mouse simulation, or coordinate automation.
4. Keep generated output local and canonical under runtime directories only.
5. Preserve hashes and provenance for provenance and rollback confidence.
6. No remote Git actions.
7. No paid-generation calls unless explicitly approved.
8. Never treat parse/test pass as Full Final Cut acceptance.

## 8) Failure modes and what to do

1. Package imports but semantics missing:
   keep blocked and investigate only this specific contract.
2. Package hash mismatch:
   reject, re-admit source, and re-plan.
3. UI stale output after edits:
   refresh planner state and cancel stale in-flight results.
4. App launch/import issue:
   re-run install, verify signature/resources, then retry.
5. Final Cut alert/abort:
   capture logs immediately and stop touching related payloads.

## 9) Fast checks for continuity

Run these after code changes:

- `git status --short`
- `git rev-parse --abbrev-ref HEAD`
- `swift build`
- `swift test`
- `sh -n Scripts/install-app`
- `make install-app`
- `codesign --verify --deep --strict /Users/marcboyer/Applications/FCPCommandConsole.app`
- `plutil -extract CFBundleIdentifier raw /Users/marcboyer/Applications/FCPCommandConsole.app/Contents/Info.plist`
- `test -f /Users/marcboyer/Applications/FCPCommandConsole.app/Contents/Resources/schemas/effect-plan.schema.json`
- `test -f /Users/marcboyer/Applications/FCPCommandConsole.app/Contents/Resources/registry/effects/native.targeted_rotate_zoom.json`
- `git diff --check`

## 10) Completion language (avoid overclaim)

Current state is best described as:

- Local planning and packaging architecture are implemented.
- Hardening on local/FCP-origin claims has improved.
- Manual Final Cut acceptance for the four target workflows is not yet complete.

Until manual and import/export gates are passed with preserved evidence, do not claim:

- “all workflows are working”
- “editable Final Cut transitions and transforms are in production behavior”
- “Phase 1 accepted”
