# Prompt for the next Claude

Read this file, then `docs/HANDOFF.md`, then
`docs/POST_PHASE1_ROADMAP.md`. Work the list in §5 below in order.

---

## 1. The product

**FrameSmith** (repository still named `FCPCommandConsole`):

> I supply the media and creative direction. FrameSmith converts ordinary
> creative language into transparent, adjustable professional editing
> operations. It should help me produce polished video essays much faster
> without becoming an autonomous video generator or replacing Final Cut Pro.

Keep this central. When a design question has two answers, prefer the one that
leaves the user more able to see and change what happened. FrameSmith is a fast,
honest front-end to real editing operations — **Final Cut is where the edit
lives, and it stays that way.**

The unit of work is a **typed primitive**, never a named effect. A "look" is an
inspectable composition of primitives that the user can open, adjust, and
partially remove. If you find yourself about to ship something the user cannot
take apart, stop — that is the failure this project is built to avoid.

---

## 2. Where things stand

Phase 1 targets four workflows: `transition.natural_dissolve`,
`motion.living_still`, `native.targeted_rotate_zoom`, `look.old_television`.

**None of the four is accepted yet.** Two are close.

What is established, all against Final Cut Pro **12.3 (450152)**:

| Contract | Status |
| --- | --- |
| `assetAdmission` | admitted — `.mov` from a package `Media/` dir resolved on first import, `src` unchanged |
| `crossDissolveTransition` | admitted — imported intact **and** duration-editable |
| `transformKeyframes` | admitted — position + scale; **rotation unobserved** |
| `opacityKeyframes` | admitted — `adjust-blend/amount`; blend modes not exercised |
| `nativeColorAdjustment` | admitted — construction only, **no language→parameter mapping** |
| `connectedOverlayLayers` | **no evidence at all** — blocks `look.old_television` |

The contract store is `service/FinalCutSemanticProfile.swift`. It is code, not
data, and scoped to one build; `evidence(forInstalled:)` returns `.unknown` on
any drift. A test reads the installed Final Cut and fails if it no longer
matches — **if that test fails, an update has silently revoked every admission
and the manual passes must be re-run.**

`standaloneFCPXMLExport` exists in `CapabilityGate` and is the route that makes
the tool usable without ever claiming a timeline mutation. The gate is done and
tested; **nothing acts on its authorization yet.**

---

## 3. The method that produced all of it

This matters more than any code in the repo. Do not abandon it for velocity.

1. **DTD validity is not acceptance.** Dissolve revisions 1 and 3 were both
   perfectly valid; one crashed Final Cut, the other was silently re-flowed.
2. **One variable per probe.** Four revisions, one change each, produced four
   durable rules. A probe that changes two things explains nothing when it fails.
3. **The returned file is the evidence** — not the sent file, not the inspector.
4. **When the encoding is unknown, capture before emitting.** The living still
   pass inverted the order and caught three findings that would each have
   shipped a silently wrong emitter, including a 10.8× position error that
   imports cleanly.
5. **Record limitations beside the admission**, never in a separate document.
6. **Observing a semantic and admitting its contract are separate acts.**

### The four dissolve construction rules

Any native transition probe should start from these:

- a real `<effect>` resource carrying the transition's UID;
- a `<filter-video>` on the transition referencing it;
- transition `offset` at `cut − duration/2`;
- adjacent clips **butt-joined** at the cut, with unused source beyond it.

Overlapping the clips is also DTD-valid and is silently rewritten — a `<spine>`
is strictly sequential.

### Three living-still encoding findings

- `position` splits into nested `X`/`Y` sub-params with separate animations;
  `scale` stays one param with paired values. They do **not** share a shape.
- `position` is **percent of frame height** though the inspector reads `px`
  (38.4 px → `3.55556`). Emitting the inspector's number pans 10.8× too far and
  imports cleanly.
- Keyframe times are **absolute source time** from a `3600s` origin in a 720000
  timescale. A keyframe at `0s` lands an hour early.

---

## 4. Hard constraints

From `docs/HANDOFF.md` §7, unchanged:

1. Never edit source media.
2. Never use the stock Final Cut app or production libraries. Launch the
   reviewed copy via `Scripts/launch-isolated-fcpcommandconsole --launch`; use
   the disposable library at
   `~/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`.
3. **GUI automation of the isolated Final Cut copy is permitted** (authorized
   2026-08-05; see HANDOFF §7 for the reasoning). Drive it yourself rather than
   handing worksheets to the user.

   Still write the worksheet **before** the run with predicted values — that
   discipline was never about who clicks, it is about not rationalizing a result
   after seeing it.

   The one rule automation adds: **never record a refusal as a finding without a
   screenshot of the UI state that refused.** A missed click and a greyed-out
   control both produce "the value didn't change", and only an image tells them
   apart. Measure perceptual questions by differencing screenshots instead of
   judging them by eye.
4. Keep generated output local and canonical under the runtime directories.
5. Preserve hashes and provenance.
6. **No remote Git actions.** Commit locally; do not push.
7. No paid-generation calls unless explicitly approved.
8. Never treat a parse or test pass as Final Cut acceptance.

Two more, learned since:

9. Probe packages are immutable once imported. The only writable part is
   `Returned/`, and a second export goes in under a **new name** — never
   overwrite before-state evidence.
10. Every vendored reference repo goes in `docs/REFERENCE_LOCK.json` with commit
    and license before it is read.

### Do not overclaim

Until a manual pass with preserved evidence says otherwise, do not write "all
workflows are working", "editable transitions and transforms are in production
behavior", or "Phase 1 accepted".

---

## 5. The work list

**In order. Do not start anything in `docs/POST_PHASE1_ROADMAP.md` Phases A–G
until every item here is done.** (A1 and the A2 gate are already complete; the
rest of Phase A is not.)

### 5.1 — Two cheap closures, both need the user at the GUI

Bundle these into one Final Cut session:

- **Play the living still probe** and confirm the four-second still actually
  renders: slow push-in, slight rightward drift, richer image, fade over the
  last twelve frames. Structural admission is not render confirmation.
- **First-import asset resolution for a still.** The living still's `.png`
  resolved by dedup against media already in the library, so that run proves
  nothing about a fresh import. Regenerate with a *different* still, or import
  into a fresh library, and confirm the package-relative `file://` resolves.

Record both in `docs/LIVING_STILL_ADMISSION_PASS.md` under Results.

### 5.2 — Living still editability pass

Same shape as `docs/DISSOLVE_EDITABILITY_PASS.md`, which is the template: pick
exact, frame-aligned values; predict the returned numbers *before* the run; stop
at the first failure.

Adjust a position keyframe, a scale keyframe, and the fade, then export and
compare. The question is whether the keyframes are natively editable or merely
round-trippable — revision 2's disabled placeholder round-tripped too.

### 5.3 — Rotation ground truth capture → `native.targeted_rotate_zoom`

Rotation's encoding is **unobserved**. Do not guess it; `transformKeyframes` is
admitted for position and scale only.

Capture first, in the pattern of `docs/LIVING_STILL_GROUND_TRUTH.md`: have the
user rotate a clip in Final Cut with keyframes, export, and read what it wrote.
Watch specifically for whether rotation nests like `position` or stays flat like
`scale`, what unit it uses (degrees vs radians vs something normalized), and how
it interacts with anchor.

Then extend `service/NativeFCPXML/NativeFCPXMLTransformChannel.swift`, build the
probe, and run an admission pass. `service/TransformMath.swift` and
`service/AspectFitPointMapper.swift` already handle the targeting math.

### 5.4 — Connected layers ground truth → `look.old_television`

`connectedOverlayLayers` has **no evidence at all** — this is the single blocker
on the fourth workflow, and the largest unknown left in Phase 1.

Capture first: a connected clip above the spine, with opacity and a blend mode.
Read how the connection, lane, and offset are encoded. Blend modes were never
exercised by any pass, so capture them here too.

Then `service/OldTelevisionComposition.swift` and `service/OverlayAdapter.swift`
become emittable, and an admission pass can run.

### 5.5 — Wire the standalone export route

`standaloneFCPXMLExport` authorizes; nothing acts on it. Connect the gate to an
actual generation path that writes a new project/package from admitted local
media, using `service/NativeFCPXML/` primitives and the probe package layout as
the model.

Two things to get right:

- The package must be self-contained: FCPXML, media, plan, provenance, import
  instructions.
- **The claim boundary must be visible in the UI**, not only in code. FrameSmith
  generates a new project. It must never word its output as though it modified
  the user's timeline.

### 5.6 — Close out Phase 1

Update `docs/HANDOFF.md` §6 and §10, admit the newly earned contracts in
`service/FinalCutSemanticProfile.swift` (with limitations recorded), and state
plainly which of the four workflows are accepted and which are not.

**If a workflow is not accepted, say so.** An honest 3-of-4 is worth more than a
claimed 4-of-4, and this project's entire value is that its claims have held up.

---

## 6. After that

`docs/POST_PHASE1_ROADMAP.md`, Phase A onward. Phase A converts the validated
workflows into something usable for real videos, which is the point of all of
this. Read the roadmap's §2 (what carries forward) and the primitive contract
before writing any of it.

---

## 7. Working notes

- **Continuity checks** after code changes: `git status --short`,
  `swift build`, `swift test`, `make test`, `git diff --check`.
- Current: **148 tests, 0 failures**; core audit `registry=4 schema=json-ok
  forbidden-patterns=0`. Branch `standalone-app`, worktree clean at `551f96b`.
- Probe executables: `swift run fcpcommandconsole-roundtrip-spike`,
  `swift run fcpcommandconsole-living-still-probe`. They are deliberately
  separate so living still work cannot disturb dissolve evidence.
- Evidence lives under `~/Movies/FCPCommandConsole/exports/`:
  `roundtrip-spikes/`, `living-still-probes/`, `ground-truth/`.
- The user has **no admin password by design** — never suggest `sudo`.
- Write the worksheet *before* the pass, with predicted values, so the result
  cannot be rationalized after the fact. `docs/DISSOLVE_EDITABILITY_PASS.md` is
  the best example of the format.
