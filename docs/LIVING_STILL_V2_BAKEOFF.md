# Living Still v2 — bakeoff

Status: **harness built, candidates defined, blocked on representative media.**

Started 2026-08-07 from HEAD `16f4e77` on `standalone-app`, macOS 26.3 arm64,
Final Cut Pro 12.3 (450152), Swift 6.3.3.

This document decides the v2 architecture from evidence. It replaces the
conclusion in `docs/LIVING_STILL_V2_DESIGN.md`, which chose two-plane native
layers because they stay editable in Final Cut. That reasoning came from a
doctrine that has since been retired: **visual quality now outranks
editability**, and the earlier decision was never tested against a rendered
depth alternative at all.

## Prerequisite gate — PASSED

Verified against code at `16f4e77`, not against the prompt's checkpoint (which
was 29 commits stale and described work that has since landed).

| Condition | Evidence |
| --- | --- |
| v1 parameters plan-driven end to end | `LivingStillCompositionBuilder.build(from: plan)`; targeted emitter enforces exact registry key match (`StandaloneFCPXMLExport.swift:272–285`) |
| Preview and export share one construction | both resolve through `emitter.channels()` via `AppModel.effectChannels(for:)` |
| Typed → schema → re-admission → capability | `PlanRevision.swift:38, 42, 47, 53` |
| Revision invalidates stale export state, safe identity | `operationID = UUID()` (`PlanRevision.swift:37`); app clears `package`/`exportedProject` (`FCPCommandConsoleApp.swift:372–373`) |
| Centralized emitter discovery | `StandaloneEmitterCatalog`; the app constructs no emitters directly |
| Inspector exposes only working parameters | `ParameterExposure` + `docs/PARAMETER_LIVENESS.md` |
| Suite and audit | 282 tests, 0 failures; `registry=4 schema=json-ok forbidden-patterns=0` |

## Feasibility established

**Apple Vision foreground instance masking is available** — revision 1, ships
with the OS, runs offline, needs no model download and no acquisition decision.
Candidates B and D are therefore testable today at zero dependency cost. This is
why the analysis pipeline was built first.

**No Core ML depth model is installed.** Candidate C requires acquiring Depth
Anything V2 Small (Apache-2.0 upstream; Apple publishes Core ML variants). Not
yet requested, because the bakeoff should not acquire a dependency before the
cheaper candidates have been measured.

`service/LivingStillAnalysis.swift` implements orientation normalization,
subject finding, coverage, and a boundary-complexity heuristic.
`fcpcommandconsole-bakeoff` runs it and writes mask visualizations outside git.

### First real result

`living-still.png` (the synthetic fixture) returns **`subject = none`**, and the
harness correctly declines to produce a mask.

That is the outcome that matters most for honesty: a scene with no foreground
subject must not be given an invented one. A two-plane construction on a
no-subject image is exactly how cardboard-cutout motion happens, and the
analyzer refuses rather than guessing.

## Candidates

| | Approach | Dependencies | Status |
| --- | --- | --- | --- |
| **A** | v1 native push/pan/colour/fade | none | control and fallback, not a v2 candidate |
| **B** | Vision two-plane parallax — subject matte, alpha PNG foreground, reconstructed plate, native lanes | none (Vision is OS) | testable now |
| **C** | Core ML monocular depth → depth-aware warp, rendered movie | Depth Anything V2 Small | blocked on acquisition decision |
| **D** | Hybrid — Vision matte for the subject edge, depth for intra-scene geometry, rendered | both | blocked with C |

Candidate B's alpha-in-a-connected-layer behaviour is **unadmitted**. The
connected-layer contract was admitted only for an opaque lane-1 overlay, so B
needs its own Final Cut capture before any claim is made about it.

## Rubric

Scored 0–5. Visual quality and intent fidelity carry the highest weight;
editability is a secondary score and explicitly **not** a veto.

| Criterion | Weight |
| --- | --- |
| Perceived depth | 3 |
| Camera-motion coherence | 3 |
| Subject-edge quality | 3 |
| Disocclusion / clean-plate quality | 3 |
| Face, hand, text, straight-line stability | 3 |
| Temporal smoothness | 2 |
| Border / crop safety | 2 |
| Colour and profile fidelity | 2 |
| Preview/export agreement | 2 |
| Latency and memory | 1 |
| Offline reliability | 1 |
| User adjustability | 1 |
| Final Cut editability | 1 |
| Package size and implementation burden | 1 |

### Hard artifact vetoes

A candidate cannot become the default if ordinary test images show any of these
at the intended motion strength, regardless of score:

- foreground halo
- exposed hole or black border
- duplicated edge strip
- rubber-sheet face or body distortion
- bent architecture or text
- depth inversion (background moving in front)
- visible layer seam or detached sticker motion
- gamma, colour-space, orientation, or aspect drift
- unstable frame-to-frame sampling

## Blocker — representative media

**The bakeoff cannot honestly run on the current fixture set.** It contains
`clip-a.mov`/`clip-b.mov` (colour bars) and `living-still.png` (a synthetic
rectangle pattern). None of them can show a hair matte, a halo, a bent line, or
a disocclusion hole, which are the failures the rubric exists to catch.

A second, practical constraint: **macOS TCC blocks command-line access to
`~/Downloads`, `~/Documents`, and `~/Desktop`.** The app can read those through
the open panel's powerbox, but the bakeoff CLI gets `Operation not permitted`.

So representative images must be placed somewhere the CLI can read. The approved
runtime root works and is already outside git:

```
~/Movies/FCPCommandConsole/fixtures/bakeoff/
```

### Needed scene classes

1. close portrait with hair detail
2. full body with hands and thin limbs
3. animal or irregular organic subject
4. product or object with crisp edges
5. architecture with straight lines
6. landscape with no obvious foreground subject
7. layered scene with several depth planes
8. image containing text, signage, or repeated pattern
9. low-light or low-contrast image
10. portrait-oriented image in a landscape output frame

Ten images, one per class, is enough. They are read locally, never uploaded, and
never modified.

## Decision

**Not yet made.** It will record which construction becomes the default, which
becomes the editable alternative, which remains the fallback, what was rejected
and why, and what evidence would justify revisiting it.

Per the prompt: if no candidate clearly beats v1 on the representative set, no
v2 ships. A worse effect with a better name is not a milestone.
