# FCPCommandConsole Handoff (for Claude)

Date: 2026-08-04
VISIBLE CHECKPOINT MARKER: latest handoff text is present in this file.
Last handoff refresh commit: 8aad9b0 (latest push to origin/standalone-app).

Goal: private local-first Final Cut command assistant.
Current objective: finish Phase 1. **The section 5 import blocker is cleared.**

## 0) Current checkpoint

- Repository: `/Users/marcboyer/Developer/FCPCommandConsole`
- Branch: `standalone-app`
- Last substantive commit: `9b2970d` (`Record the dissolve duration-editability
  pass`). `HEAD` itself is the checkpoint bump that records this line, so it is
  always one commit ahead of the hash named here — do not treat that as drift.
- Worktree: clean
- Build/test evidence: `swift build` passed; `swift test` passed **97 tests,
  0 failures**; `make test` core audit passed — measured at `6695230`, the last
  commit touching code. `749ab9e` and `4f5732b` are documentation only.
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

## 5) The import/export blocker — CLEARED 2026-08-04

Four probe revisions, each changing one thing so each failure had one cause.
Full analysis in `docs/ROUNDTRIP_MANUAL_PASS.md`; summary in
`docs/PHASE1_ACCEPTANCE.md`.

| Rev | Operation | Construct | Outcome |
| --- | --- | --- | --- |
| 1 | `A78B1B9D-…` | `asset-clip` import | crash in `addAssetClip:` |
| 2 | `CA7D0733-…` | bare `<transition>`, no effect, no offset | imported disabled at `offset="0s"` |
| 3 | `6B8F8B1C-…` | full effect + centred offset + overlapping clips | effect admitted, spine re-flowed |
| 4 | `27EA1706-…` | full effect + centred offset + butt-joined clips | **admitted intact — all rows pass** |

Crash history to preserve:

- crash report `/Users/marcboyer/Library/Logs/DiagnosticReports/Final Cut Pro-2026-08-03-082455.ips`
- incident id `42DFFCF1-9E45-41DA-992F-ADB212422B07`
- FCP version/build: 12.3 / 450152

### The construction rules this bought

1. A `<transition>` needs a real `<effect>` resource carrying the transition's
   UID and a `<filter-video>` referencing it. Omitting either is DTD-valid and
   semantically inert.
2. The transition's `offset` is `cut − duration/2`.
3. The adjacent clips **butt-join** at the cut. They must not overlap; a
   `<spine>` is strictly sequential and Final Cut silently re-flows it.
4. Both clips need unused source beyond the joint for the dissolve to consume.

Rules 1 and 3 each produce perfectly valid documents that Final Cut rewrites
without complaint. This is the concrete case for constraint 7 in section 7.

The Cross Dissolve UID `FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265` is derived
from Final Cut's own `Filters.bundle` `Info.plist` (`PAECrossDissolve`,
protocol `FxTransition`), not guessed.

**Do not trust `reference/…/upstream_otio_fcpxml/fcpx_transitions.fcpxml` for
spine geometry.** It encodes the overlapping form that revision 3 proved Final
Cut rejects. It is OTIO writer output, never validated against Final Cut.

All four packages are spent evidence: do not modify, regenerate, or retry them.

Standing manual rules, unchanged:

- Perform exactly one manual pass per package.
- Stop at the first crash, alert, missing transition, missing media, or export mismatch.
- Record results before any mutation or retry.
- Only admit contracts that match observed behavior.

## 6) Remaining technical work before all four workflows can be claimed

Items 1–4 of the code list are done; see section 4b. Item 1 below is done.
What is left cannot be done in code alone.

1. ~~One successful import/export roundtrip for the minimal dissolve contract.~~
   **Done 2026-08-04** (revision 4). Other contracts still require their own
   manual evidence — nothing about transform, opacity, color, or overlays
   follows from this.
2. Workflow validations, each needing its own manual pass:
   - natural dissolve manual duration edits — **passed 2026-08-04**. `⌃D` →
     `120` on the revision 4 project moved the transition from 30f to 50f and
     Final Cut recomputed `offset` to 185f on its own, keeping the dissolve
     centred on the unmoved 7 s cut. Same effect UID, no re-flow, three-line
     whole-document diff. The dissolve is native and editable, not merely
     round-trippable. Evidence: `docs/DISSOLVE_EDITABILITY_PASS.md` and
     `…/27EA1706-…/Returned/after-duration-edit.fcpxmld`.
     **Edge-dragging was not exercised** and is still unproven.
   - targeted rotate/zoom keyframe editability — **encoding captured
     2026-08-05** (`docs/ROTATION_GROUND_TRUTH.md`): rotation is a single param
     in plain degrees, `anchor` is a paired *attribute*, and a movie clip's
     keyframes start at `0s` rather than the stills' `3600s`. A follow-up
     capture settled the `position` sign convention (Final Cut's +Y is up,
     measured from viewer screenshots) and showed static `position` is also a
     paired attribute. Emitter and probe built, and the **admission pass passed
     2026-08-05** — see `docs/NATIVE_EFFECT_ADMISSION_PASS.md`. Rotation, scale,
     and the compensating position track all returned with their values intact.

     One normalisation: the nested `X`/`Y` sub-param form we emitted came back
     collapsed into a single paired-value `position` param. Both axes shared
     keyframe times, and the paired form is canonical when they do. Final Cut
     accepted our form and rewrote it, so this is a construction difference
     rather than a rejection — but the emitter should match it.

     **Editability has not been run.** Predictions are locked in the same
     document.
   - old TV overlays/controls are native-editable in Final Cut — **encoding
     captured 2026-08-05** (`docs/CONNECTED_LAYERS_GROUND_TRUTH.md`): a
     connected clip is a *child* of the spine `asset-clip` with `lane="1"`,
     blend mode is `mode="14 (Overlay)"`, and its `offset` is **parent-relative**.
     Emitter and probe built, and the **admission pass passed 2026-08-05** — see
     `docs/NATIVE_EFFECT_ADMISSION_PASS.md`. The connected `<video>` returned
     with `lane="1"`, `offset="1s"`, `start="3600s"`, and
     `<adjust-blend amount="0.5" mode="14 (Overlay)"/>` all intact, alongside an
     animated flicker and the Color Adjustments filter on the spine clip.

     That closes `connectedOverlayLayers`, which had been the only contract of
     the six with no evidence of any kind.

     **Editability has not been run.** Its predictions are locked in the same
     document, and edit 2 tests something no pass has tried: editing a *static
     attribute* rather than a keyframed param.

   Both captures produced one general rule, confirmed independently on four
   properties: **static values are attributes on the effect element, animated
   values are `<param>` children.** An emitter must choose a shape per
   property *and* per animated-or-not; both wrong shapes are DTD-valid.
   - living still movement/fade/color editability — **historical 2026-08-04
     evidence stage.** Before its emitter existed, the order was inverted:
     Final Cut wrote the encoding first. **Ground truth captured 2026-08-04**, full
     analysis in `docs/LIVING_STILL_GROUND_TRUTH.md`. Three findings that would
     each have produced a silently wrong emitter:
     1. `position` splits into nested `X`/`Y` sub-params with separate
        animations, while `scale` stays one param with a paired value. The two
        do **not** share a shape.
     2. `position` is **percent of frame height**, though the inspector reads
        `px`: 38.4 px was written as `3.55556`. Emitting the inspector's number
        pans 10.8× too far and imports cleanly — a wrong magnitude, not a
        rejection.
     3. Keyframe times are **absolute source time** — a still gets
        `start="3600s"` and keyframes are offset from that hour in a 720000
        timescale. A keyframe at `0s` lands an hour early.

     Colour is `filter-video` → `<effect uid="FxPlug:7E2022A5-202B-4EEB-A311-AC2B585D01B0"/>`
     ("Color Adjustments", internally `PAEHDRColorCorrect`) — neither candidate
     guessed from `Filters.bundle`. Its three opaque payloads decode to a
     `{pluginVersion: 3}` stamp and two untouched-default `ozml` blobs, so the
     channel looks synthesisable; whether Final Cut accepts it without them is
     an admission question, not something the capture settled.

     **Emitter written 2026-08-04** (`ba2bb32`). Reusable primitives live in
     `service/NativeFCPXML/` — rational time with the 3600s source origin, a
     small node renderer, still resources, transform channel, opacity channel,
     and a Color Adjustments template. They are meant to serve
     `native.targeted_rotate_zoom`, native fades and colour, and the native
     portions of `look.old_television`, not just this effect. **Rotation is
     deliberately unimplemented**: its encoding is unobserved, and rotate/zoom
     must capture it the same way before emitting one.

     `LivingStillProbeBuilder` is parallel to `FCPXMLRoundTripSpikeBuilder` and
     deliberately *not* factored together with it, so no living still change can
     alter what a dissolve regeneration emits. Its export-root guard also
     refuses to write beneath `exports/ground-truth`.

     Probe `3E660E97-DBD8-40EA-88F9-C926CD424FDE`; procedure, read-out table and
     results in `docs/LIVING_STILL_ADMISSION_PASS.md`. Its `adjust-transform`,
     `adjust-blend`, all 18 `filter-video` params, and the `effectConfig`
     payload are **byte-identical** to Final Cut's own export; the wrapper
     differs on purpose (no `<library location>`, no invented `uid`/`sig`).
     128 tests pass, core audit clean, valid against the installed 1.14 DTD and
     correctly rejected by 1.13.

     **Imported and returned intact 2026-08-04 23:05.** The `<video>` subtree
     came back structurally identical — all 40 nodes, every keyframe, every
     param, all three payloads. All three ground-truth findings held under
     import, not just export: the nested-`X`/`Y`-vs-paired-`scale` asymmetry was
     not normalised, `3.55556` was not rescaled, and the `3600s` origin was not
     reinterpreted. Final Cut assigned the asset `uid` and `media-rep/@sig`
     itself, vindicating the choice not to invent them.

     Two gaps this pass leaves open. Asset resolution was satisfied by
     **dedup against media already in the library** from the ground-truth
     capture (returned `src` points at the `Living Still Ground Truth` media
     folder; identical sha256), so first-import resolution into a clean library
     is untested. And playback was never reported, so structural admission is
     recorded but on-screen render is not.

     The generated construction is admitted. Editability is not — that is a
     separate pass, as the dissolve work showed.
3. ~~A trustworthy contract store.~~ **Done 2026-08-05** (`551f96b`),
   `service/FinalCutSemanticProfile.swift`. Admission could not be a file the
   app reads and believes, because the gate deliberately prevents a JSON claim
   from becoming capability evidence. So the store is **code, not data**: the
   memberwise initializer is internal and `Codable` is not conformed, which puts
   adding an admission behind a source edit and review — the same bar
   `VerifiedFinalCutSelectionEvidence` sets.

   It is scoped to Final Cut **12.3 (450152)**, the only build any pass has run
   against; `evidence(forInstalled:)` returns `.unknown` on any drift, so an
   update silently revokes every admission until the passes are re-run. A test
   reads the installed application and fails on mismatch. Each record binds its
   contract to the worksheet and the sha256 of the returned XML that admitted
   it, and carries that pass's limitations, so a caveat cannot be lost by living
   somewhere else.

   Five of six contracts are admitted: `assetAdmission`,
   `crossDissolveTransition`, `transformKeyframes`, `opacityKeyframes`,
   `nativeColorAdjustment`. `connectedOverlayLayers` is absent — no probe has
   exercised a connected layer — so `look.old_television` stays blocked, which
   is correct rather than unfortunate.
4. The standalone export route. `standaloneFCPXMLExport` was added to
   `CapabilityGate` in the same pass and is **not** a weaker `fcpxmlExport`.
   `fcpxmlExport` asserts that an existing timeline may be modified, which is
   why it demands `VerifiedFinalCutSelectionEvidence` and can never be satisfied
   by local media. Standalone export asserts only that a new project was written
   to disk, so it requires `AdmittedLocalMediaEvidence` — every plan source
   matched on both canonical path and digest — and refuses a timeline selection
   outright as a category error. Semantic contracts still apply in full.

   **Wired 2026-08-05** (`1a0b15c`), `service/StandaloneFCPXMLExport.swift`.
   The gate runs first, a `StandaloneEffectEmitter` turns the plan into FCPXML,
   and the result is a self-contained package with media, provenance, and import
   instructions. The package README and provenance both state that FrameSmith
   generated a new project and did not open, read, or modify an existing
   timeline; a test asserts that wording survives. Provenance records the exact
   Final Cut build whose profile authorised the export.

   This paragraph records the 2026-08-05 wiring checkpoint. Current HEAD has
   production emitters for all four effects: `motion.living_still`,
   `native.targeted_rotate_zoom`, `transition.natural_dissolve`, and
   `look.old_television`. Their registered shared construction descriptors are
   used for export; the app's current visual viewer does not render the
   two-clip transition or connected-overlay descriptors. Old Television's
   production contract is a native FCPXML base treatment plus an optional
   admitted-still overlay, not generated FFmpeg/static/scanline assets.
   Historical returned contracts do not establish every current emitter
   instantiation, current app integration, the canonical 12-frame dissolve, or
   the optional overlay. The remaining next gaps are a fresh real-Final-Cut
   import for the canonical 12-frame dissolve, a real-Final-Cut/perceptual
   exercise for Old Television's optional admitted-still overlay, and the
   Living Still v2 depth-model acquisition decision.
5. Current planning is in `docs/POST_PHASE1_ROADMAP.md`; the next gaps are the
   canonical 12-frame dissolve import, the Old Television optional-overlay
   evidence pass, and the Living Still v2 depth-model acquisition decision.

## 7) Evidence and safety constraints to preserve

1. Never edit source media.
2. Never use stock Final Cut app or production libraries.
3. **GUI automation of the isolated Final Cut copy is permitted — authorized by
   the user 2026-08-05.** This replaces the previous blanket prohibition on
   AppleScript, Accessibility, keyboard/mouse simulation, and coordinate
   automation.

   The prohibition was protecting two different things, and only one of them
   ever needed a human:

   - *Not damaging real work.* Still protected, but by constraint 2, not by
     this one. The isolated launcher's separate `HOME` and the disposable
     library are what make automation safe; who drives the mouse is irrelevant
     to that.
   - *Evidence integrity.* Never depended on this at all. The returned FCPXML
     is the evidence, and it is exactly as authoritative whether a human or a
     script clicked Export. "The returned file is the evidence" was always the
     rule, and automation does not touch it.

   What automation genuinely does introduce is a **third** risk the old rule
   never had to name: a missed click and a refused control are
   indistinguishable from their absence of effect. A human has continuous
   visual feedback; a script has none unless forced. So:

   **A refusal may never be recorded as a finding without a screenshot showing
   the UI state that refused it.** A greyed-out field is a finding. A click
   that landed three pixels off is not. Only an image separates them, and
   "the value didn't change" separates them not at all.

   Two further rules:

   - A screenshot is evidence of *what the UI did*, never of a semantic. It
     does not substitute for the returned XML and cannot admit a contract.
   - Automation is scoped to the isolated Final Cut copy and the reviewed
     `FCPCommandConsole.app`. Nothing else on the machine is in scope.

   Where automation is *better* than a human: perceptual questions get
   **measured rather than judged**. "Does it look richer?" was answered by eye
   during the living still pass and produced a genuinely ambiguous result; the
   same question answered by differencing two screenshots is a number.
4. Keep generated output local and canonical under runtime directories only.
5. Preserve hashes and provenance for provenance and rollback confidence.
6. **Pushing to `origin` is permitted** (authorized 2026-08-06). Commit locally
   as you go and push when work reaches a coherent state. Still no force-push to
   a shared branch, no history rewriting, and no destructive remote operations
   without asking.
7. **Paid generation is permitted within the configured budget**
   (`service/CostPolicy.swift`). Ask before a single operation that would be
   unusually expensive or before raising the budget itself — not before ordinary
   spend inside it.
8. Never treat parse/test pass as Full Final Cut acceptance.

### On these constraints generally

Items 1, 2, and 8 protect things that cannot be recovered: the user's source
media, the user's real Final Cut libraries, and the truthfulness of the project's
claims. They are not style preferences and they do not trade against output
quality — nothing about not deleting someone's footage makes an effect look
worse. Keep them.

Everything else here is procedure. If a rule in this file is stopping you from
producing a better result for the user, that rule is wrong and should be changed
in the same commit as the work — say what you changed and why. Do not ship a
worse-looking result to comply with a document.

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

**Phase 1 closed out 2026-08-05.** Full statement in `docs/PHASE1_ACCEPTANCE.md`.

Current state is best described as:

- All four target workflows have **admission and editability evidence** against
  Final Cut 12.3 (450152), each backed by a returned FCPXML cited by digest in
  `service/FinalCutSemanticProfile.swift`.
- All six semantic contracts are admitted, and every one records an explicit
  editability position — confirmed with a digest, or explicitly not established.
- The standalone export route is **proven end to end**: real media through
  admission, the gate, an emitter, a package, a hand import, and a structurally
  identical return.

What may now be claimed, precisely: *the generated constructions for these four
effects are accepted and editable in this Final Cut build.*

Still do **not** claim:

- "FrameSmith can make these effects from a description" — no
  creative-language-to-parameter mapping is observed for any effect. Every probe
  reused a captured value.
- "the app does these workflows" — the emitters and the route are reachable from
  CLIs and tests only. App integration is Phase A.
- "these effects work" unqualified — each contract is narrow. Lane 1 only,
  Overlay only, Saturation only, no keyframed anchor, no retiming, no masks.
- "this will keep working" — every admission is scoped to build 450152 and is
  revoked on drift by design. A test fails when the installed build stops
  matching.
- editability of anything untested: Color Adjustments parameters, dissolve
  edge-dragging, blend-mode changes, and media relinking all remain unproven.
