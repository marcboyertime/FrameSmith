# FrameSmith — post-Phase-1 roadmap

Status: **Phase 1 complete.** All four effects have production emitter-backed
new-project FCPXML export. Living Still v2 and Old Television v2 now use one
shared rendered-effect contract: preview reads the exact checksum-bound
video-only ProRes 422 HQ movie that export copies into a connected lane above
the unchanged source. A 10-source production matrix produced 20 accepted four-
second HQ movies and passed bounded visual review. Hardened Final Cut 12.3 round
trips passed for the connected rendered-movie layer over both still and movie parents. The
canonical 12-frame Natural Dissolve route remains construction-tested and still
needs a fresh real-Final-Cut import. Future work remains quality-first and must
retain the same evidence split between pixels, construction, and deployment.

**Truthful rendered comparison checkpoint complete in source:** rendered
options now own admitted per-option preview artifacts, A/B/C uses one shared
frame transport, rendered export cannot render, continuous controls use
draft/commit semantics, and preparation is bounded, deduplicated, cancellable,
and latest-generation safe. The next implementation package is the schema-v3
composition core described in `docs/SCHEMA_V3_COMPOSITION_DESIGN.md`; it begins
only after this branch's installed-app evidence, dissolve pass/blocker, CI, and
review are sealed.

The repository is still named `FCPCommandConsole`. **FrameSmith** is the product
name used throughout this document; renaming is a Phase A chore, not a
prerequisite.

---

## 1. What FrameSmith is

> I supply the media and creative direction. FrameSmith converts ordinary
> creative language into transparent, adjustable professional editing
> operations. It should help me produce polished video essays much faster
> without becoming an autonomous video generator or replacing Final Cut Pro.

Four clauses in that sentence are load-bearing, and every item below is
answerable to them:

| Clause | What it forbids |
| --- | --- |
| *ordinary creative language* | Requiring the user to know parameter names, units, or FCPXML |
| *transparent* | Any operation the user cannot open up and read |
| *adjustable* | Any operation the user cannot change or partially remove |
| *not an autonomous generator, not a Final Cut replacement* | Anything that takes the edit away from the user |

The last one sets the ceiling deliberately. FrameSmith is a **fast, honest
front-end to real editing operations**. Final Cut remains where the edit lives.

### The goal

**Make the best-looking result the user asked for.** That is the point of the
product, and it outranks every structural preference in this document. If a
technique produces a materially better image, use it — layered, rendered,
ML-assisted, external compositor, whatever wins.

Two things to get right while doing that, neither of which is a reason to ship
something worse:

1. **Keep the recipe.** Retain the parameters, source identities, revision data,
   and provenance that let the operation be understood and regenerated at a
   different strength. The failure mode worth avoiding is not "rendered" — it is
   *unrepeatable*. A tool whose answer to "same thing but less" is "regenerate
   it from these numbers" is fine. A tool whose answer is "I don't know what I
   did" is not.
2. **Say what the user got.** Editable in Final Cut, regenerable in FrameSmith,
   or fixed. Never imply more adjustability than exists.

Typed primitives and inspectable compositions remain a good default because they
usually make both of those easy — not because structure is worth more than the
picture. When they conflict, the picture wins and the recipe gets recorded.

---

## 2. What carries forward from Phase 1

Phase 1 produced a working method, and it is more valuable than any of the code.
It must survive into every phase below.

1. **DTD validity is not acceptance.** Dissolve revisions 1 and 3 were both
   perfectly valid; one crashed Final Cut, the other was silently re-flowed.
   Schema conformance predicts nothing.
2. **Change one thing per probe.** Four revisions, one variable each, produced
   four durable construction rules. A probe that changes two things explains
   nothing when it fails.
3. **The returned file is the evidence.** Not the sent file, not the UI, not the
   inspector. What Final Cut writes back is the only observation.
4. **Capture before emitting, when the encoding is unknown.** The living still
   pass inverted the order — Final Cut wrote the encoding first — and caught
   three findings that would each have shipped a silently wrong emitter,
   including a 10.8× position error that imports cleanly.
5. **Observing a semantic and admitting its contract are separate acts.**
   `FinalCutSemanticProfile` is code, not data, and scoped to one build.
6. **Record limitations beside the admission**, never in a separate document
   where they can be lost.

### The primitive contract

Phase B formalizes this, but it applies from Phase A onward. **Every** operation
FrameSmith can perform must declare, in the registry:

| Field | Question it answers |
| --- | --- |
| `native` | Is this native FCPXML, or does it require a render? |
| `editable` | Does it stay adjustable in Final Cut after import? |
| `contract` | Which `FCPXMLSemanticContract` admits it? |
| `bounds` | What parameter range is verified — and what happens outside it? |
| `preview` | How is it shown before commit? |
| `fallback` | What happens when the contract is not admitted? |
| `verification` | What manual pass established it, and what did that pass *not* establish? |

An operation that cannot fill all seven is not ready to ship. This is the
mechanism that keeps "systems, not effects" true in practice rather than in
spirit.

---

## 3. The dependency spine

Why this order, in one pass:

```
A. Productionize          ← converts validated workflows into a usable tool
      │                      (without this, everything else is unusable research)
      ▼
B. Primitive library      ← the actual product surface; typed, bounded, editable
      │
      ├──────────────► C. Recipes          (compositions of B — needs B complete)
      │
      ▼
D. Targets/masks/tracking ← the capability that unlocks "professional"
      │                      (text behind subjects, selective grade, tracked labels)
      ▼
E. Transitions/compositing ← needs D's masks and B's primitives
      │
      ▼
F. Motion graphics        ← needs D for tracked/behind-subject text
      │
      ▼
G. Editorial + audio      ← independent of D/E/F; can run in parallel after B
      │
      ▼
Final. Generative         ← only after conventional editing is strong
```

Two notes on the spine:

- **G is parallelizable.** Transcript editing, silence removal, and captions
  depend on B but not on masks or compositing. If Phase D stalls on
  segmentation quality, G is the productive detour — and for a video essay
  workflow it may deliver more time savings per hour of work than D or E.
- **C is not a phase so much as a proof.** If the recipes in C cannot be built
  purely from B's primitives, then B is incomplete and the correct response is
  to go back to B, not to special-case the recipe.

---

## Next Phase A: productionize the standalone tool

**Goal:** carry the validated workflows into a tool usable for real videos and
complete the evidence and control coverage that the shipped emitters still
need.

**Done when:** the user can go from a folder of media and a sentence of
direction to an importable Final Cut project, without touching a terminal.

### A1. Version-scoped semantic profile — ✅ **done**

`service/FinalCutSemanticProfile.swift`, scoped to Final Cut **12.3 (450152)**.
It admits the currently documented contracts, including rotation and connected
overlays, and fails closed on version drift. See `STATUS.md` for the bounded
claim rather than extrapolating it to another Final Cut build.

### A2. Standalone FCPXML export capability — ✅ **done for current emitters**

`standaloneFCPXMLExport` exists in `CapabilityGate` and requires canonical
admitted local media, a valid schema-v2 plan, and effect-scoped contracts. It
refuses a timeline selection as a category error. `StandaloneFCPXMLExportBuilder`
also validates the registry/plan/media relationship, resolves the shared
emitter catalog, stages safely, and publishes a new-project package only after
those checks pass.

The claim boundary must stay explicit in the UI, not just in code: FrameSmith
**generates a new project**. It does not modify an existing timeline, and must
never word its output as though it had.

### A3. Shared emitter integration — ✅ **done for all four effects**

The app and standalone export dispatch the same plan-driven construction
descriptors for Living Still, Targeted Rotate + Zoom, Natural Dissolve, and Old
Television. Native effects share one channel construction. Living Still v2 and
Old Television v2 share one sealed prepared movie between preview and export;
export is not allowed to render a second copy. Natural Dissolve remains a two-
clip export construction rather than a single-media visual-viewer claim.

### A4. Shared effect construction descriptors — ✅ **done for all four emitters**

All four effects use registered shared construction descriptors for export.
Rendered effects pass a verified `RenderedEffectAsset` containing the exact
source, recipe, construction, timing, media, and movie identities. Preview
opens its file; export checksum-verifies and copies it. Living Still v2 and Old
Television v2 both passed the 10-case visual matrix, while the common connected
rendered-movie FCPXML layer passed still- and movie-parent Final Cut 12.3 return
verification.

Preview strategy is per-primitive (it is one of the seven contract fields) and
will not be uniform. Expect three tiers:

1. **Native-parameter preview** — reproduce the transform/opacity/color math
   locally. Exact for the primitives Phase 1 admitted.
2. **Rendered preview** — for anything requiring a real render.
3. **Indicative preview** — clearly labelled as approximate.

A preview that silently misrepresents the result is worse than no preview.
Tier 3 must be visually distinct from tiers 1 and 2.

**Colour needs a before/after toggle, not only a rendered frame.** During the
historical native v1 playback check, the motion and fade were immediately
visible, but the colour change was not confirmable by eye — a Saturation of 25 on that image sat
below the threshold where a human watching full-motion playback could tell it
had applied. If the user cannot tell whether an operation happened, a preview
that just shows the result has failed at its only job. Every colour primitive
therefore needs an explicit A/B affordance. Expect the same to be true of
subtle grain, vignette, and diffusion in Phases B and C.

### A5. Visible, editable parameter controls — ✅ **done**

The revision inspector presents only metadata-declared live controls. It gives
invariants and unsupported values an explanatory read-only state, validates
numeric drafts and patches atomically, and supports reset/reset-all to the
original baseline. Bounds and exposure come from registry metadata, not a UI
guess based on parameter presence.

### A6. Effect stacking in one plan — next package

The schema currently carries one `effectID` per plan. Stacking requires an
ordered list with defined composition semantics — and an answer to what happens
when two primitives touch the same channel.

**This is a schema change.** Treat it as schema v3 with the same migration
discipline v2 got: legacy plans quarantined, not silently reinterpreted.
The current design boundary is recorded in
`docs/SCHEMA_V3_COMPOSITION_DESIGN.md`; no graph types or schema-v3 runtime were
implemented by the truthful-comparison checkpoint.

### A7. Versioning: duplicate, regenerate, restore, history

Duplicate a version, regenerate from a modified plan, restore a previous
version, and inspect export history. The provenance layer (`service/Provenance.swift`)
already records enough to make this real rather than cosmetic.

### A8. Self-contained export package

One directory containing: the FCPXML, any renders, layer sources, the plan,
full provenance, and import instructions. The dissolve and living still probe
packages are the prototype — that layout worked and should be generalized.

---

## Next Phase B: professional primitive library

**Goal:** a library of typed, bounded, individually verified operations. This is
the real product surface. Everything after this phase is composition.

**Done when:** every primitive below either ships with all seven contract fields
filled, or is explicitly recorded as unavailable with the reason.

### The primitives

Grouped by system, not listed as features:

**Geometry** — `scale`, `position`, `rotation`, `anchor targeting`, `crop`

Position, scale, and rotation are admitted in the current scoped evidence.
`native.targeted_rotate_zoom` emits signed rotation through its shared channels;
anchor targeting is what makes "zoom toward *that*" work and is the reason
`AspectFitPointMapper` and `TransformMath` exist. New geometry primitives still
need their own capture/evidence rather than inheriting this admission.

**Compositing** — `opacity`, `blend mode`, `connected layers`

Opacity keyframes and connected overlay layers are admitted in the current
scoped evidence. The newer connected rendered-movie layer is admitted over both
a still and a movie parent in Final Cut 12.3. Old Television v2 uses this movie
layer for a sustained typed CRT render; it no longer uses the retired native
base/optional-still recipe. Blend-mode breadth and arbitrary layer stacking
remain unproven. `motion.opacity.fade.v1` is a separate reference-only card, not
a fallback for either rendered v2 effect.

**Color** — `exposure`, `contrast`, `saturation`, `temperature`, `tint`,
`monochrome`, `vignette`

The Color Adjustments *construction* is admitted, carrying all 18 params and
three opaque payloads. What is **not** established is any mapping from creative
language to parameter values — the probe reused a captured `25`. Phase B's real
work here is that mapping, and it needs its own evidence.

Vignette is not a Color Adjustments param; it needs its own investigation
(likely a separate effect UID, possibly a generator + blend).

**Optical** — `blur`

Native blur must be located the way Color Adjustments was — by capture, not by
guessing from `Filters.bundle`. That guess already failed once.

**Time** — `speed changes`, `freezes/holds`

Untouched by Phase 1. Retiming interacts with keyframe times, which are absolute
from the `3600s` source origin — expect that interaction to be the hard part.

**Transitions** — `native transitions`

Cross dissolve is admitted with four construction rules. Other native
transitions are *likely* to follow the same shape, but "likely" is not admitted;
each needs a probe. The four rules make those probes cheap.

**Audio** — `audio fades and crossfades`

The dissolve pass produced an unplanned observation: Final Cut attached an
`FFAudioTransition` companion automatically. Worth pulling on before building
anything.

**Text** — `titles and overlays`

Deliberately last in B and expanded in F. Titles are where Motion templates
enter, and that is a different admission problem.

### Sequencing within B

Do the **capture-first** primitives before the emit-first ones. Rotation, blur,
vignette, and blend modes all have unobserved encodings; each needs a ground
truth capture in the pattern of `docs/LIVING_STILL_GROUND_TRUTH.md`. Batch the
captures — one Final Cut session can produce several — then emit against them.

---

## Next Phase C: transparent professional recipes

**Goal:** composable looks that remain inspectable graphs of primitives.

**Recipes:** VHS, old film, CRT, noir, dreamlike diffusion, light leak, handheld
drift, glitch, archival footage, slow cinematic push.

### The rule that defines this phase

A recipe is **a named set of primitive instances with parameter values and an
order**. Nothing else. It must be possible to:

- see every primitive the recipe contains, with its values;
- change any one of them;
- remove any one of them and keep the rest;
- save the result as a new recipe.

**A recipe that can only be delivered as a render still ships** — as long as its
parameters survive so the user can regenerate it dimmer, stronger, or without one
of its parts. "Unexplained" is the failure, not "rendered".

Prefer expressing a recipe as primitives when that gets you the same image,
because it makes the adjust-one-part case trivial. But if VHS looks genuinely
better as a shader pass than as a stack of native primitives, ship the shader
pass, expose its parameters, and move on. Do not withhold a good-looking result
to protect an architectural preference.

Where a recipe *does* decompose cleanly, that is still worth noticing as a signal
about Phase B: "handheld drift" as position + rotation keyframes with noise means
those primitives are pulling their weight.

---

## Next Phase D: targets, masks, and tracking

**Goal:** the capability that most separates amateur from professional output.

**Unlocks:** text behind subjects, tracked glows, selective blur/color, sky-only
effects, foreground wipes, window/doorway masks, object-centered motion.

### Systems

**Selection** — point, box, polygon masks, mask refinement, mask preview
**Tracking** — point tracking, object tracking, propagated video masks, manual
correction of drift

### On the AI segmentation options

Evaluate, **do not blindly adopt**:

| Candidate | Role | Watch for |
| --- | --- | --- |
| `eisneim/sam2.1_mlx` | Apple-Silicon segmentation + propagation | Maturity; MLX version pinning; fidelity vs upstream |
| `facebookresearch/sam2` | Reference implementation | Weight licensing; runtime cost on this machine |
| `facebookresearch/co-tracker` | Point tracking | Licensing; whether it beats Vision for this use |
| OpenCV | Classical tracking, mask ops | Dependency weight |
| Apple Vision / Core ML | Native segmentation and tracking | Already on the machine; no extra license |

Evaluate **Apple Vision first** — it is present, licensed, fast, and needs no
vendoring. Adopt SAM2 only where Vision demonstrably fails on real footage.

### The non-negotiable

**Manual point, box, and mask workflows must remain available when AI
segmentation is unavailable.** Not as a degraded path — as a first-class one. A
tool that stops working when a model fails to load is not a tool.

Drift correction is part of this: any propagated mask must be manually
correctable at any frame. Automatic tracking that cannot be fixed by hand is
unusable for finished work.

### Admission question specific to D

Masks raise a question Phase 1 never faced: **is a mask native FCPXML, or is it
a render?** Final Cut has native shape and color masks. If they can be emitted,
masked operations stay editable; if not, every masked effect becomes a baked
layer, which changes the product substantially. **Settle this with a capture
before building anything else in D.**

---

## Next Phase E: professional transitions and compositing

**Goal:** a transition/compositing adapter with an explicit preference order.

### Result first, then editability

**Pick the approach that produces the best result. Then tell the user what they
got.**

This used to be a strict preference order with native FCPXML always winning and
a baked render as "last resort". That rule cost real quality: the living still
v2 design chose layered parallax over a depth-warp specifically because the
former stays editable. The representative matte review then exposed a hard
silhouette and hair fringe; the continuous depth candidate won the production
bakeoff and now ships as retained-recipe rendered output. That is the concrete
case for refusing the old trade on the user's behalf.

The tiers still exist, but as a **description of what you produced**, not a
ranking you must climb:

| Tier | Editable where | Use when |
| --- | --- | --- |
| Native FCPXML | in Final Cut | it genuinely looks as good |
| Motion/FxPlug template | in Final Cut | native can't express it |
| External composition | elsewhere, round-trippable | the look needs a real compositor |
| Rendered layer | nowhere — regenerate to change | the result is materially better |

Choosing a lower tier for a better-looking result is **correct**, not a
compromise. What is not acceptable is doing it silently.

### The obligation that replaces the preference order

Every operation records, in provenance and in the UI:

- what tier it used;
- whether the user can adjust it in Final Cut, adjust it in FrameSmith by
  regenerating, or not at all;
- if it is rendered, the exact parameters that produced it, so regenerating with
  a tweak is always possible.

A rendered layer that the user can regenerate at a different strength is a
perfectly good outcome. A rendered layer whose settings are lost is not — that
is the only version of "baked" worth refusing, and the fix is to keep the recipe,
not to avoid the render.

### Candidates to evaluate

| Candidate | Role | License note |
| --- | --- | --- |
| `gl-transitions/gl-transitions` | Parameterized shader transition designs | Check per-transition licenses; they vary |
| `MetalPetal/MetalPetal` | Mac-native Metal processing/compositing | Good fit for tier 4 renders |
| `NatronGitHub/Natron` | External editable node graphs | GPL — process boundary only, never linked |
| `NatronGitHub/openfx-misc` | OFX plugin set | GPL |
| `NatronGitHub/openfx-gmic` | G'MIC OFX | GPL |

The Natron/OFX line is the tier-3 candidate: an external composition the user
can open and edit. That is strictly better than a bake, and its licensing is
manageable **as long as it stays a separate process**, never a linked library.

### Initial advanced effects

Luma reveal, blur dissolve, light leak, zoom/whip, displacement melt, foreground
wipe, portal through a confirmed mask.

### Explicit sequencing instruction

**Do not implement portal first.** It is the most impressive and the most
dependent. Build the shared primitives first:

- masks (from D)
- tracking (from D)
- transition progress
- source/destination handling
- displacement
- feathering
- compositing

Portal is then a composition of those, and so are the other six. Building portal
first produces exactly the flattened one-off this roadmap exists to prevent.

---

## Next Phase F: motion graphics for video essays

**Goal:** the reusable text and graphic systems a video essay actually runs on.

### Systems

**Typography** — titles, lower thirds, kinetic typography, quotations,
highlighted captions
**Spatially bound text** — text behind subjects (needs D), tracked labels (needs D)
**Explanatory graphics** — arrows, callouts, diagrams
**Layout** — picture-in-picture, image collages

### Approach order

1. **Apple Motion templates first.** A Motion template that appears in Final
   Cut's own effects browser is editable by the user in the place they already
   work. That is a better outcome than anything generated. Investigate what a
   `.moti`/published-parameter template requires and whether FrameSmith can emit
   one with parameters bound.
2. **`remotion-dev/remotion`** for source-preserved programmatic motion
   graphics — **subject to its current license.** Remotion's licensing has
   commercial-use conditions that must be read and recorded in
   `docs/REFERENCE_LOCK.json` before any adoption. If the license does not fit,
   the correct answer is to not use it, not to work around it.

Text behind subjects is the flagship: it needs F's typography, D's segmentation,
and E's compositing. It is a good final integration test for those three phases.

---

## Next Phase G: editorial and audio acceleration

**Goal:** the largest raw time saving in the whole roadmap for a video essay
workflow. Effects make a video look better; **editorial makes it exist.**

### Systems

**Transcript-driven editing** — transcript editing, captions
**Automatic pass reduction** — silence/filler removal, scene detection, beat
detection, markers
**Audio finishing** — dialogue leveling, audio fades/crossfades, loudness
normalization, music ducking

### Study

| Source | What to take |
| --- | --- |
| `WyattBlue/auto-editor` | Silence/filler detection heuristics that hold up on real speech |
| SpliceKit (already vendored at `reference/elliotttate/SpliceKit`, MIT) | Silence, scene, caption, beat features |
| `0xsline/OpenChatCut` | Conversational edit interface patterns |
| `browser-use/video-use` | Video-as-input interaction patterns |
| `Memories-ai-labs/vea-open-source` | Editing-agent architecture |

SpliceKit is already vendored and MIT-licensed — start there.

### Why G may deserve to jump the queue

If Phase D stalls on segmentation quality, G is the productive detour. For a
video essay, transcript editing and silence removal plausibly save more hours
than every effect in B and C combined. Consider running G in parallel once B is
stable.

### The output-format question

Decide early whether editorial output is an FCPXML with cuts and markers
(editable, native, preferred) or a rendered assembly. Markers and compound
structure are likely emittable and should be captured like anything else.

---

## Final Phase: optional generative processing

**Only after conventional editing and compositing are strong.**

Image-to-video, object removal, background reconstruction, model-generated
environmental motion, generative transition bridges.

Evaluate `Lightricks/LTX-Video`, ComfyUI (already vendored,
`reference/Comfy-Org/ComfyUI`, **GPL-3.0**), and appropriate paid providers
within the configured budget (`service/CostPolicy.swift` already exists).

### The governing rule

**Prefer an editable conventional operation when it reaches the required
quality.** A layered, rendered, or generative construction is allowed when it
materially wins on the requested result, provided FrameSmith preserves the
source identities, chosen settings, generated assets, revision lineage, and
provenance needed for an honest future edit. Opaque output with no retained
revision record remains unacceptable.

That distinction matters for object removal, background reconstruction, and
motion beyond a modest 2.5D treatment: refusing a clearly better result merely
because it is not native would violate the quality-first doctrine. The UI and
provenance must state the tier used and its editability limits.

`reference/BrokenSource/DepthFlow` (**AGPL-3.0**) is worth noting here: depth-based
parallax is a *conventional* operation that covers a large share of what people
reach for image-to-video to accomplish, and it is deterministic and adjustable.
Prefer it over generation where it suffices — but note the AGPL obligations
before any integration deeper than reference reading.

---

## Cross-cutting: license discipline

`docs/REFERENCE_LOCK.json` already records name, path, source URL, commit, and
license for every vendored repository. **Every candidate named in this roadmap
must be locked that way before it is read as reference, and its license
evaluated before it is adopted as a dependency.**

Currently vendored licenses include GPL-3.0 (ComfyUI) and AGPL-3.0 (DepthFlow).
Those are fine to *read*; they constrain how code may be *shipped*. Maintain the
distinction explicitly:

| Use | Constraint |
| --- | --- |
| Reference reading | Any license, must be locked |
| Separate process / CLI invocation | GPL/AGPL generally workable; record the boundary |
| Linked library | Permissive only, unless the whole product accepts the license |

Remotion (Phase F) and the SAM2 weights (Phase D) are the two most likely to
have terms that do not fit. Read them before building on them.

---

## Current gate and next evidence milestone

Phase 1 is complete for the present scope. The table below records current
implementation truth, not a prohibition on beginning future work:

| Item | Status |
| --- | --- |
| Living Still v2 | ✅ pinned local Core ML depth render at 0.90 depth motion/0.030 push; one inference reused across 120 default frames; 10-case ProRes 422 HQ visual/stream pass; exact prepared-movie preview/export parity; still-parent Final Cut 12.3 return |
| Targeted Rotate + Zoom | ✅ production emitter, confirmed-target transform/rotation path |
| Rotation semantics | ✅ admitted in the current Final Cut 12.3 (450152) scoped profile |
| Connected rendered-movie semantics | ✅ admitted over still and movie parents in the current Final Cut 12.3 (450152) scoped profile |
| Standalone export route | ✅ validated registry/media/emitter route, new-project-only package publication |
| Natural Dissolve | ✅ production emitter, shared export construction descriptor, and construction-tested canonical read-only 12-frame route; 2026-08-07 real-import evidence covers the earlier 30-frame construction, so a fresh 12-frame import remains open; visual viewer does not render its two-clip transition descriptor |
| Old Television v2 | ✅ sustained content-addressed CRT movie with scanlines/noise/tube geometry/chroma/ghosting/bloom/jitter/vignette/≤2% micro-flicker; 10-case visual pass; exact prepared-movie parity; still- and movie-parent Final Cut 12.3 returns |

The next work is not to relitigate Phase 1 or productionize an already-shipped
emitter. Keep Living Still's head-only 0.033–0.100 second startup hold as an
explicit temporal regression metric; obtain a fresh real-Final-Cut import for the
canonical 12-frame dissolve; then widen effect stacking, calibrated color,
masking/tracking, typography, and audio with their own scoped evidence. Existing
evidence remains version-, construction-, and media-scoped; it does not
substitute for expert/population perceptual evaluation or broad compatibility.

---

## What would make this roadmap fail

Recorded plainly, because these are the realistic failure modes and naming them
is cheaper than rediscovering them:

1. **Shipping results that look mediocre because a cleaner approach existed.**
   This is now listed first deliberately. The user is making video essays that
   have to hold up on screen; an elegant architecture that produces a flat image
   has failed at the only thing that matters. Structural preferences lose to the
   picture.
2. **Shipping a recipe that cannot be *regenerated*.** Note the change: not
   "cannot be taken apart". A rendered look whose parameters are retained is
   fine — the user asks for less and gets less. A look whose settings are gone
   is the real failure, because there is no path back to a different version.
3. **Admitting a contract on a passing probe alone.** A probe shows Final Cut
   accepted *one* construction. The profile must stay narrow, versioned, and
   honest about what each pass did not establish.
4. **Letting the standalone route drift into a mutation claim.** It generates a
   new project. If the UI ever implies it edited the user's timeline, the
   distinction the gate enforces becomes a lie the product tells.
5. **Claiming more adjustability than exists.** Rendered is fine; rendered while
   the UI implies it is editable is not.
6. **Optimizing for effect count over editorial speed.** For a video essay, the
   bottleneck is assembling and cutting, not the look. Phase G addresses the
   actual bottleneck and should not be perpetually deferred behind more visible
   work.

Note what is *not* on this list any more: reaching for generation, rendering
instead of emitting native, or building a flagship effect before its primitives.
Those are engineering judgement calls, not failures. Make them on the merits of
the result.
