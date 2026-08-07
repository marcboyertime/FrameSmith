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

All four effects now have production emitters. Natural dissolve and old
television were generalized out of their probe builders and admitted by real
import on 2026-08-07.

**Not claimed:** no creative-language-to-parameter mapping exists; colour is
indicative only; no audio, typography, masking, or tracking; old television's
connected overlay is unexercised by its emitter; and no frame-by-frame
comparative image-quality bakeoff has been run.

## Current implementation checkpoint

Phase 1 is complete at the current repository checkpoint. `swift test` and
`make test` pass **215 tests**; the latter also reports
`core audit: registry=4 schema=json-ok forbidden-patterns=0`. `swift build -c
release` also passes. The installed app was rebuilt/reinstalled and its code
signature and resource parity were verified.

Installed-UI acceptance is **partially confirmed by hand** (2026-08-06): media
admission, the target picker, planning, standalone generation, and the effect
preview were all exercised in the running app by the user, which found two bugs
tests could not — silently rejected target clicks and content clipping below the
fold. The parameter inspector's controls have not yet been exercised that way.

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
| Production standalone emitters | Living Still and Targeted Rotate + Zoom. Their shared channels drive preview and FCPXML. |
| Explicitly unavailable effects | Natural Dissolve and Old Television, pending their own generalized emitters. |
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
both while planning and revising. Natural Dissolve and Old Television have
catalogued unavailable reasons shared by preview and export.

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
libraries is part of FrameSmith. Source media and production libraries remain
untouched. A passing package, DTD validation, or unit test is not by itself a
broad perceptual or future-version acceptance claim.

## Remaining limitations and next work

The next milestone is to productionize Natural Dissolve and Old Television
through the same registry → validated plan → shared channels → preview/FCPXML
architecture. Their emitters need focused evidence and regression coverage;
they must not be simulated as currently available. Effect stacking, history,
and additional primitives remain future work.

Living Still v2 is not being started by this checkpoint. Revisit it only under
the quality-first doctrine: useful editability is preferred, but a layered,
rendered, or ML-assisted approach is acceptable where it materially improves
quality and retains FrameSmith-level revision/provenance data.
