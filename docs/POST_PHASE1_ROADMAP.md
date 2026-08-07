# FrameSmith — post-Phase-1 roadmap

Status: **Phase 1 complete.** Living Still and Targeted Rotate + Zoom have real emitter-backed previews and new-project FCPXML export; Natural Dissolve and Old Television remain unavailable rather than simulated. Future work remains quality-first: Living Still v2, rendered/ML/generative options, and professional expansion are possible only with fresh evidence.

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

### The failure this roadmap is designed to avoid

The tempting shape for a tool like this is a menu of named looks — "VHS",
"noir", "glitch" — each implemented as whatever produced an acceptable frame.
That shape collapses within a month of real use, because the second request is
always *"same thing but less"*, and a flattened one-off has no *less*.

So: **no phase below ships a named effect as its unit of work.** The units are
typed primitives, and looks are inspectable compositions of them. A recipe the
user cannot take apart is a bug, not a feature.

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

**Goal:** convert the validated workflows into a tool usable for real videos.
This is first priority because everything currently proven is only reachable
through manual probe scripts.

**Done when:** the user can go from a folder of media and a sentence of
direction to an importable Final Cut project, without touching a terminal.

### A1. Version-scoped semantic profile — ✅ **done**

`service/FinalCutSemanticProfile.swift`, scoped to Final Cut **12.3 (450152)**.
Admits five contracts; `connectedOverlayLayers` deliberately absent. Fails
closed on any version drift. See HANDOFF §6 item 3.

### A2. Standalone FCPXML export capability — ⚠️ **gate done, emitter route not**

`standaloneFCPXMLExport` exists in `CapabilityGate` and requires canonical
admitted local media, a valid schema-v2 plan, and effect-scoped contracts. It
refuses a timeline selection as a category error.

Remaining: wire it to an actual export that generates a new project/package.
The gate authorizes; nothing yet acts on the authorization.

The claim boundary must stay explicit in the UI, not just in code: FrameSmith
**generates a new project**. It does not modify an existing timeline, and must
never word its output as though it had.

### A3. Integrate the native emitters into the SwiftUI app

`service/NativeFCPXML/` currently serves probe executables only. Move it behind
the app's job path so the same primitives serve preview, export, and packaging.

### A4. Real effect preview, not source-only preview

Today the app previews the source. That is honest but nearly useless — the user
cannot judge an operation they cannot see.

Preview strategy is per-primitive (it is one of the seven contract fields) and
will not be uniform. Expect three tiers:

1. **Native-parameter preview** — reproduce the transform/opacity/color math
   locally. Exact for the primitives Phase 1 admitted.
2. **Rendered preview** — for anything requiring a real render.
3. **Indicative preview** — clearly labelled as approximate.

A preview that silently misrepresents the result is worse than no preview.
Tier 3 must be visually distinct from tiers 1 and 2.

**Colour needs a before/after toggle, not a rendered frame.** During the living
still playback check the motion and the fade were immediately visible, but the
colour change was not confirmable by eye — a Saturation of 25 on that image sat
below the threshold where a human watching full-motion playback could tell it
had applied. If the user cannot tell whether an operation happened, a preview
that just shows the result has failed at its only job. Every colour primitive
therefore needs an explicit A/B affordance. Expect the same to be true of
subtle grain, vignette, and diffusion in Phases B and C.

### A5. Visible, editable parameter controls

Every parameter in the plan gets a control. This is where "adjustable" stops
being a claim and becomes a fact. Bounds come from the primitive contract.

### A6. Effect stacking in one plan

The schema currently carries one `effectID` per plan. Stacking requires an
ordered list with defined composition semantics — and an answer to what happens
when two primitives touch the same channel.

**This is a schema change.** Treat it as schema v3 with the same migration
discipline v2 got: legacy plans quarantined, not silently reinterpreted.

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

Position and scale are admitted (Phase 1). **Rotation is not** — its encoding is
unobserved, and `native.targeted_rotate_zoom` must capture it the same way the
living still captured transform before emitting one. Anchor targeting is what
makes "zoom toward *that*" work and is the reason `AspectFitPointMapper` and
`TransformMath` already exist.

**Compositing** — `opacity`, `blend mode`, `connected layers`

Opacity keyframes are admitted. Blend modes were **not** exercised by the living
still pass. Connected layers have **no evidence at all** and are the single
blocker on `look.old_television`.

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

**Do not turn recipes into unexplained flattened filters.** If a recipe can only
be delivered as a baked render, it does not ship in C — it goes back to B as a
missing primitive.

This is also the honest test of Phase B. "Handheld drift" should be position +
rotation keyframes with noise; if it cannot be expressed that way, rotation is
missing, and that is a B problem surfacing in C.

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

### Preference order

1. **Native FCPXML** — fully editable in Final Cut
2. **Editable Motion/FxPlug-style effect** — editable, external
3. **Preserved external editable composition** — editable elsewhere, round-trippable
4. **Baked render** — last resort

The adapter picks the highest tier the operation and admitted contracts allow,
and **records which tier it used** in provenance. The user must be able to see
that a given transition was baked rather than native.

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

**Never use generative processing when an editable conventional operation can
produce the requested result.**

This is not a stylistic preference. A generative result is opaque, unrepeatable,
and unadjustable — it violates *transparent* and *adjustable* simultaneously. It
is justified only where no conventional operation exists at all: removing an
object from a moving shot, reconstructing a background, inventing motion in a
still beyond what a 2.5D parallax can do.

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

## Gate: what "current phase complete" means

**No Phase A–G or Final Phase implementation may begin until all of the
following are complete.** Current status:

| Item | Status |
| --- | --- |
| Living Still emitter | ✅ done (`ba2bb32`) |
| Living Still admission pass | ✅ passed 2026-08-04, returned intact |
| Editability pass (dissolve) | ✅ passed 2026-08-04 |
| Living Still editability | ❌ not run |
| Targeted transform | ❌ rotation encoding unobserved; no capture, no emitter |
| Old Television layers | ❌ `connectedOverlayLayers` has no evidence at all |
| Natural dissolve | ✅ admitted and editable |
| Standalone export route | ⚠️ gate done (`551f96b`); emitter wiring not done |

Two smaller gaps recorded during the passes, both cheap:

- **Living still playback** was never visually confirmed — structural admission
  is not render confirmation.
- **First-import asset resolution for the still** rode on dedup against media
  already in the library. The dissolve pass covers this for `.mov` from a
  package `Media/` directory; the still does not.

See `docs/NEXT_CLAUDE_PROMPT.md` for the ordered work list.

---

## What would make this roadmap fail

Recorded plainly, because these are the realistic failure modes and naming them
is cheaper than rediscovering them:

1. **Shipping a recipe that cannot be taken apart.** The moment one look is a
   baked special case, the primitive library stops being the product and becomes
   overhead. Phase C is where this pressure will be strongest.
2. **Admitting a contract on a passing probe alone.** A probe shows Final Cut
   accepted *one* construction. The profile must stay narrow, versioned, and
   honest about what each pass did not establish.
3. **Letting the standalone route drift into a mutation claim.** It generates a
   new project. If the UI ever implies it edited the user's timeline, the
   distinction the gate enforces becomes a lie the product tells.
4. **Building portal, or any flagship effect, before its primitives.** Named
   explicitly in Phase E because it is the most likely single instance.
5. **Reaching for generation because it is faster than solving the editing
   problem.** The Final Phase rule exists for this exact temptation.
6. **Optimizing for effect count over editorial speed.** For a video essay, the
   bottleneck is assembling and cutting, not the look. Phase G addresses the
   actual bottleneck and should not be perpetually deferred behind more visible
   work.
