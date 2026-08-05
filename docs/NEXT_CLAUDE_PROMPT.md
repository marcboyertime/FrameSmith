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
| `transformKeyframes` | admitted — position + scale, and editable; **rotation captured 2026-08-05 but its generated form is unimported** |
| `opacityKeyframes` | admitted — `adjust-blend/amount`; blend modes captured, not admitted |
| `nativeColorAdjustment` | admitted — construction only, **no language→parameter mapping** |
| `connectedOverlayLayers` | **not admitted** — encoding captured 2026-08-05, probe generated, import not run. Blocks `look.old_television`. |

The contract store is `service/FinalCutSemanticProfile.swift`. It is code, not
data, and scoped to one build; `evidence(forInstalled:)` returns `.unknown` on
any drift. A test reads the installed Final Cut and fails if it no longer
matches — **if that test fails, an update has silently revoked every admission
and the manual passes must be re-run.**

`standaloneFCPXMLExport` is the route that makes the tool usable without ever
claiming a timeline mutation. Gate and generation path are both done
(`service/StandaloneFCPXMLExport.swift`), with emitters for `motion.living_still`
and `native.targeted_rotate_zoom`.

**The only thing between here and a closed-out Phase 1 is running the two queued
admission passes** — see §5.5b. Both probe packages are generated and waiting.

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
- Keyframe times are absolute from a `3600s` origin in a 720000 timescale. A
  keyframe at `0s` lands an hour early. **This is a property of stills, not a
  rule** — the rotation capture showed a movie clip's keyframes starting at
  `0s`, and the origin cannot be read off the asset either.

### The rule both 2026-08-05 captures produced

> **Static values are attributes on the effect element. Animated values are
> `<param>` children.**

Confirmed independently on `position`, `anchor`, `rotation`, and
`adjust-blend/amount`. Choose a shape per property **and** per
animated-or-not; both wrong shapes are DTD-valid.

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

### 5.1 — ✅ playback confirmed / ❌ one closure left

- **Living still playback — done 2026-08-05.** Push-in, drift and fade all
  visible; colour confirmed by A/B toggle. All three channels render.
- **First-import asset resolution for a still — still open.** The living
  still's `.png` resolved by dedup against media already in the library, so that
  run proves nothing about a fresh import. Regenerate with a *different* still,
  or import into a fresh library, and confirm the package-relative `file://`
  resolves. (`assetAdmission` is admitted on the dissolve's `.mov` evidence, so
  this is a completeness gap, not a blocker.)

### 5.2 — ✅ Living still editability pass — done 2026-08-05

Passed. Scale 108→120%, position X 38.4→54 px returning exactly `5`, opacity
0→25% returning `0.25`. Keyframes are natively editable, and the
percent-of-height conversion is confirmed in the edit direction too.

One unpredicted finding: editing one position axis writes a keyframe on **both**.
See `docs/LIVING_STILL_EDITABILITY_PASS.md`.

### 5.3 — Rotation → `native.targeted_rotate_zoom`

**Capture done 2026-08-05** — `docs/ROTATION_GROUND_TRUTH.md`. Rotation is a
single `<param>` in plain degrees; `anchor` is an **attribute** on
`adjust-transform`, percent of frame height on both axes; movie-clip keyframes
start at `0s`, not the stills' `3600s`.

**Remaining:** extend `service/NativeFCPXML/NativeFCPXMLTransformChannel.swift`
with rotation and anchor, build a probe, run an admission pass.
`service/TransformMath.swift` and `service/AspectFitPointMapper.swift` already
handle the targeting math.

### 5.4 — Connected layers → `look.old_television`

**Capture done 2026-08-05** — `docs/CONNECTED_LAYERS_GROUND_TRUTH.md`, two
captures. A connected clip is a **child** of the spine `asset-clip` with
`lane="1"`; blend mode is `mode="14 (Overlay)"`; and critically the connected
clip's **`offset` is parent-relative, not timeline-relative**.

**Remaining:** add a connected-layer primitive and a blend-mode channel to
`service/NativeFCPXML/`, then `service/OldTelevisionComposition.swift` and
`service/OverlayAdapter.swift` become emittable and an admission pass can run.

### 5.4b — The rule that came out of both captures

> **Static values are attributes on the effect element. Animated values are
> `<param>` children.**

Confirmed independently on `adjust-transform` (static `anchor` attribute vs
animated `rotation` param) and `adjust-blend` (static `amount` attribute vs the
living still's animated `amount` param).

The emitter must therefore choose a shape per **property × animated-or-not**,
not per property. This is the highest-value thing to get right in the next code
pass, because both wrong shapes are DTD-valid.

### 5.5 — ✅ Standalone export route — wired 2026-08-05

`service/StandaloneFCPXMLExport.swift`. Gate first, then a
`StandaloneEffectEmitter`, then a self-contained package with media,
provenance, and import instructions. The claim boundary is asserted by a test.

**Remaining:** emitters for `transition.natural_dissolve` (generalise the
two-clip construction out of `FCPXMLRoundTripSpikeBuilder`) and
`look.old_television` (blocked on its contract). And the claim boundary is
currently visible in the *package*; surfacing it in the **app UI** is Phase A.

### 5.5b — Run the two queued admission passes

**This is the only thing standing between here and a closed-out Phase 1.**

Both probe packages are generated, DTD-valid, and waiting under
`~/Movies/FCPCommandConsole/exports/native-effect-probes/`. Procedure and
predicted values in `docs/NATIVE_EFFECT_ADMISSION_PASS.md`.

If they pass, admit `connectedOverlayLayers` into
`service/FinalCutSemanticProfile.swift` — a separate, deliberate edit, with the
returned artifact digests and the limitations each pass did not establish.

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
