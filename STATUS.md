# FrameSmith status

## Editorial Intelligence Foundation — 2026-08-07

The director-control contract is a **tested runtime invariant**, not prose.
`EditorialStructureLock` captures ordered media identity, timeline placement,
duration, source in-point, retiming, sync, protected regions, and
narration/music digests; 19 adversarial tests assert that reordering, omitting,
duplicating, substituting, retiming, slipping sync, or moving an edit point is
refused. Validation compares fields rather than only a fingerprint, because a
hash says *that* something changed and a director deserves to know *what*.

Eleven provenance-bearing technique cards: **5 validated, 6 reference_only**.
Validated means this repository built the construction and a returned FCPXML
admitted it — never that a source described the technique.

Surprise Me ships for one scenario end to end: a single admitted still with a
confirmed focal target returns three materially different treatments, each
carrying the same editorial-structure fingerprint. Coverage, diversity
reasoning, manual verification, and limitations are recorded in
`docs/editorial-intelligence/BAKEOFF_AND_COVERAGE.md`.

All four effects now have production emitters. Natural Dissolve and Old
Television were generalized out of their probe builders and admitted by real
import on 2026-08-07. Old Television subsequently gained an optional overlay
plan role and a generated connected-overlay path. That implementation and its
FCPXML construction are tested, but the changed overlay path has not yet had a
fresh real-Final-Cut or perceptual exercise.

**Not claimed:** no creative-language-to-parameter mapping exists; colour is
indicative only; no audio, typography, masking, or tracking; no fresh real-
Final-Cut or perceptual exercise has covered Old Television's changed overlay
path; and no frame-by-frame comparative image-quality bakeoff has been run.

## Current implementation checkpoint

Phase 1 is complete at the current repository checkpoint. `swift test` and
`make test` pass **290 tests**; the latter also reports `core audit: registry=4
schema=json-ok forbidden-patterns=0 cards=11 (reference_only=6 validated=5)`.
`swift build -c release` also passes. The installed app was rebuilt/reinstalled
and its code signature and resource parity were verified.

Installed-UI acceptance is **confirmed by hand** (2026-08-08) in the reviewed
installed app. With `portrait-frame-subject.png`, Living Still and Targeted
Rotate + Zoom controls changed live; the preview was scrubbed to `0.40s`;
malformed and contradictory drafts were refused while the last live plan
remained; and Reset all restored defaults. The UI generated standalone projects
at `/Users/marcboyer/Movies/FCPCommandConsole/exports/standalone/7C81170C-842E-47F9-811B-12A8E1AB1CEA`
and `/Users/marcboyer/Movies/FCPCommandConsole/exports/standalone/DC5430C9-46A4-4DD6-9BCE-D4659483DDF3`.
Inspection of their FCPXML recorded Living Still scale `1.47`, vertical position
`20`, and end opacity `0.2`, plus Targeted scale `1.69` and rotation `48`.
Final Cut was not opened or modified for these two exports.

Note for anyone reading an older copy of this file: it previously said "project
policy forbids scripted UI control". That has not been true since 2026-08-05 —
HANDOFF §7 constraint 3 permits GUI automation of the **isolated** Final Cut
copy and of the reviewed app, and every Phase 1 admission and editability pass
was driven that way.

FrameSmith is the product name; existing repository, package, bundle, and
command identifiers remain `FCPCommandConsole`.

| Capability | Current state |
| --- | --- |
| Local SwiftUI workflow | Admits local stills/movies read-only, computes source identities, plans locally, and provides a revision inspector. |
| New-project output | Standalone export creates a new Final Cut project package and never mutates an existing timeline. |
| Production standalone emitters | All four effects. Their shared channels drive both preview and FCPXML. |
| Old Television overlay | The plan model now carries an optional admitted-still overlay and the emitter generates its connected layer; the changed path remains unevaluated by a fresh real-Final-Cut or perceptual pass. |
| Editorial structure lock | Ordered media, timing, retiming, sync, and protected regions are machine-checked before planning, preview, and export. |
| Technique cards | 11 provenance-bearing cards, 5 validated and 6 reference-only; only validated cards whose capabilities are admitted may be offered. |
| Surprise Me | Up to three materially different treatments for one shipped scenario; never changes clips, order, timing, or sync. |
| Parameter liveness | Registry metadata classifies every parameter as editable, approximate, invariant, or unsupported/read-only; unsupported controls are not made editable by omission. |
| Inert local package | Copies admitted bytes and plan/provenance only; it is not FCPXML, an effect render, or an importability claim. |

## Parameter and export truth

Plan revisions are prospective and atomic: every patch is type/bounds checked,
semantically validated, schema checked, and verified against the admitted media
before becoming a new operation identity. Reset and reset-all restore the
recorded baseline without changing request, selection, inputs, or source
identity.

Living Still supports its declared duration, scale, pan, opacity, and fade
controls. Targeted Rotate + Zoom supports declared duration, scale, and signed
rotation with a confirmed normalized target. Movie duration overflow is refused
both while planning and revising.

Natural Dissolve and Old Television gained generalized emitters on 2026-08-07
and were admitted by real import. The dissolve refuses rather than adapts when
handle is insufficient: the requested duration is never shortened and the edit
point is never moved to make an effect fit.

Old Television's later optional overlay role is validated as an admitted still
and its emitter is covered by the connected-overlay construction test. That
test and package/FCPXML evidence do not establish a new Final Cut import or a
perceptual result for the changed path.

Color and easing remain intentionally bounded. Living Still uses a captured
Saturation 25 construction as an indicative adapter; no arbitrary color
calibration, perceptual quality result, or general easing encoding is claimed.
See [docs/PARAMETER_LIVENESS.md](docs/PARAMETER_LIVENESS.md).

## Final Cut evidence boundary

The admitted semantic profile is scoped to Final Cut Pro **12.3 (build
450152)** and fails closed on version drift. It admits only the documented
construction contracts, including the currently evidenced transform, rotation,
opacity, native color-adjustment, cross-dissolve, and connected-overlay
semantics. It does not prove every effect, arbitrary value mapping, visual
quality, or compatibility with another Final Cut build.

All outputs preserve the non-mutation boundary: no UI automation, AppleScript,
Accessibility control, timeline selection inference, or modification of user
libraries is part of **the shipped product**. (Development-time GUI automation
of the isolated Final Cut copy is permitted and is how the evidence above was
gathered; it is not a runtime capability of FrameSmith.) Source media and production libraries remain
untouched. A passing package, DTD validation, or unit test is not by itself a
broad perceptual or future-version acceptance claim.

## Remaining limitations and next work

Natural Dissolve and Old Television are production emitters admitted by returned
evidence, so that milestone is closed. Old Television's optional overlay role
and connected-layer generation landed after that checkpoint; fresh real-Final-
Cut and perceptual exercise of that changed path remain open.

The next work, in rough value order: exercise Old Television's generated overlay
path in a fresh real-Final-Cut and perceptual pass; measure a
creative-language-to-parameter mapping for colour so it stops being indicative
only; run the representative-media bakeoff in
`process.review.representative_bakeoff.v1` for comparative image quality; and
widen Surprise Me beyond the single-still scenario. Effect stacking, history,
masking, tracking, typography, and audio remain future work.

Living Still v2 is now in evidence-gathering, not effect implementation. Its
analysis pipeline and bakeoff harness measured all 10 classes; visual portrait
evidence demoted the Vision two-plane candidate, while the continuous-warp
candidate leads but remains untested pending a depth-model acquisition decision.
No v2 render, Final Cut admission, or perceptual quality result is claimed.
