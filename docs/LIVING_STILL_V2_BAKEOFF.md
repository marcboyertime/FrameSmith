# Living Still v2 — bakeoff

Status: **harness built, candidates defined, 7 of 10 classes measured.**
Three organic classes still need real photographs.

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

## Matrix run 1 — subject analysis, 7 of 10 classes

Fixtures live in `~/Movies/FCPCommandConsole/fixtures/bakeoff/` (outside git).
Six are synthetic; `landscape-sonoma.png` is a real photograph converted from
the system wallpaper set.

Synthetic is deliberately chosen for the **geometric** classes rather than being
a compromise. Ground truth is known exactly, so a bent line, a warped glyph, or
a duplicated edge strip is *measurable* instead of a matter of opinion. Photos
are only genuinely required for the organic classes, where the failure is a
matte losing hair rather than a geometry error.

| Fixture | Class | Normalized | Subject | Complexity |
| --- | --- | --- | --- | --- |
| `architecture-grid` | 5 straight lines | 1920×1080 | **none** | — |
| `text-signage` | 8 text / pattern | 1920×1080 | **none** | — |
| `landscape-sonoma` | 6 landscape (real photo) | 6016×6016 | **none** | — |
| `product-crisp` | 4 crisp edges | 1920×1080 | single, 13.5% | 0.003 |
| `layered-depth` | 7 depth planes | 1920×1080 | **multiple (2)** | 0.003 |
| `portrait-frame` | 10 portrait | 1080×1920 | single, 6.1% | 0.002 |
| `low-contrast` | 9 low contrast | 1920×1080 | single, 4.9% | 0.003 |

### What this already decides

**The `subject = none` cases are a routing signal, not a failure.** Architecture,
text, and a real landscape all correctly return no foreground instance. Those
images must never receive a two-plane layered treatment — there is nothing to
put on the near plane, and forcing one is exactly how cardboard-cutout motion
happens. Auto must route them to a depth method or to v1.

That this holds on a **real 6016×6016 photograph** and not only on synthetic
fixtures is what makes it trustworthy.

**Ambiguity is detected rather than guessed.** `layered-depth` returns
`multiple (2)`, which is the case that requires the user to pick a subject
before a subject-dependent treatment can be offered honestly.

**Portrait orientation survives normalization.** `portrait-frame` reports
1080×1920 and still finds its subject, so the orientation pipeline is not
silently transposing the mask.

### Honest gap in this run

Every complexity score is 0.002–0.003, because synthetic shapes have clean
edges. **The heuristic is therefore untested at the high end**, which is the
hair-and-fur case it exists to detect. A threshold tuned against these numbers
alone would be meaningless.

Three classes remain uncovered, and they are precisely the organic ones:

- close portrait with hair detail
- full body with hands and thin limbs
- animal or irregular organic subject

## Blocker — representative media

The original fixture set — colour bars and a rectangle pattern — could show
none of the failures the rubric exists to catch. Six purpose-built synthetic
fixtures plus one real photograph now cover seven classes (see run 1 above).

**Three organic classes remain, and synthetic cannot substitute for them.** A
drawn shape has a clean edge by construction, so it cannot exercise a matte
losing hair, fringing on a thin limb, or fur against a busy background. The
boundary-complexity heuristic is likewise unexercised above 0.003.

A second, practical constraint: **macOS TCC blocks command-line access to
`~/Downloads`, `~/Documents`, and `~/Desktop`.** The app can read those through
the open panel's powerbox, but the bakeoff CLI gets `Operation not permitted`.

So representative images must be placed somewhere the CLI can read. The approved
runtime root works and is already outside git:

```
~/Movies/FCPCommandConsole/fixtures/bakeoff/
```

### Still needed — three images

1. close portrait with visible hair detail
2. full body with hands and thin limbs
3. animal or irregular organic subject

Drop them in `~/Movies/FCPCommandConsole/fixtures/bakeoff/`. They are read
locally, never uploaded, and never modified. Rough matches are fine — the point
is coverage of failure modes, not photographic quality.

## Decision

**Not yet made.** It will record which construction becomes the default, which
becomes the editable alternative, which remains the fallback, what was rejected
and why, and what evidence would justify revisiting it.

Per the prompt: if no candidate clearly beats v1 on the representative set, no
v2 ships. A worse effect with a better name is not a milestone.
