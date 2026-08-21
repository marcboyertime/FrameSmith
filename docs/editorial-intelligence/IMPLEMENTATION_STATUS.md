# Editorial Intelligence Foundation — implementation status

Recorded 2026-08-08 for Final Cut Pro **12.3 (450152)**.

## Delivery boundary

This document describes the current repository and runtime evidence. Use the
current local `git log` and working tree for exact source identity. No installed-
app or remote-push claim is implied here; deployment, bundle parity, and remote
publication are separate acceptance steps.

FrameSmith is the product name. Internal repository, package, bundle, and
legacy command identifiers remain stable for compatibility.

## Runtime architecture

The treatment path is linear and fail-closed:

1. `EditorialKnowledgeCatalog` decodes the strict 15-card catalog and verifies
   identities, provenance, status, validation, risk, and required construction.
2. `EditorialStructureLock` binds ordered source identities, rational timing,
   edit points, retiming, protected regions, and audio-sync constraints.
3. `TreatmentOptionGenerator` retrieves only executable cards and returns fewer
   options rather than padding with a semantically false alternative.
4. `TreatmentAdmissionService` rechecks structure, capability, registry,
   catalog, schema, media, and exact construction immediately before use.
5. Native treatments share one admitted channel construction across preview
   and FCPXML export.
6. Rendered treatments share one sealed `RenderedEffectAsset`: preview reads the
   exact prepared movie and export verifies and copies that same SHA-256-bound
   file. It cannot render a replacement.
7. `RenderedOverlayFCPXML` places one opaque, video-only treatment movie above
   the unchanged source spine; movie-source audio remains on the spine.

Operation IDs identify user selections. Stable catalog, structure, plan,
recipe, model, depth, renderer, source, and artifact identities use canonical
SHA-256 encodings rather than process-randomized values.

## Parameter truth

Registry presentation metadata is the source of truth for liveness. The plan
carries values, validation checks them against the current registry, and the
emitter consumes those exact values.

- Living Still v2 is runtime-editable for duration, depth-motion strength,
  push, pan X/Y, and depth smoothing. Its model ID, method, output profile, and
  source-preservation rule are invariants; `outputLongEdge=1920` is a fixed
  maximum long-edge ceiling rather than a selectable export resolution.
  Revisions regenerate a baked movie; there is no native-transform or fade route.
- Targeted Rotate + Zoom remains runtime-editable for duration, scale, and
  signed rotation. A confirmed focal point is typed execution input, not an
  invented parameter.
- Natural Dissolve's canonical 12-frame duration and construction values remain
  read-only in the generic editor. Insufficient handles are refused rather
  than moving an edit point.
- Old Television v2 is runtime-editable for duration, profile, intensity,
  scanlines, noise, sync instability, chroma separation, bloom, vignette,
  ghosting, micro-flicker, and deterministic seed. The 1920-pixel maximum
  long-edge ceiling, 30 fps, render method, and source preservation are
  invariants; render resolution is not a selectable project-export control.
- Missing or unverified liveness metadata remains read-only.

See `docs/PARAMETER_LIVENESS.md` for ranges and representation boundaries.

## Starter catalog

Every card has strict schema validation and claim-level provenance. Only
`validated` cards whose required capabilities and media prerequisites pass can
be retrieved for automatic construction.

| Card ID | Status | Production boundary |
| --- | --- | --- |
| `analysis.compositing.alpha_premultiplication.v1` | reference_only | analysis guidance |
| `analysis.composition.eye_trace_bridge.v1` | reference_only | analysis guidance |
| `analysis.mask_tracking_edge_quality.v1` | reference_only | visual-review guidance |
| `audio.loudness.dialogue_intelligibility.v1` | reference_only | audio guidance; no audio emitter |
| `look.color.restrained_native.v1` | reference_only | no calibrated creative mapping |
| `look.crt.old_television.v1` | validated (version 2) | sustained rendered CRT movie through `look.old_television` |
| `motion.ease_in_out_guidance.v1` | reference_only | no admitted generic easing encoding |
| `motion.focal.target_push.v1` | validated | `native.targeted_rotate_zoom`; confirmed target required |
| `motion.opacity.fade.v1` | reference_only | retired v1 route; no dedicated admitted effect |
| `motion.still.quiet_push.v1` | validated (version 2) | continuous rendered depth movie through `motion.living_still` |
| `process.review.representative_bakeoff.v1` | reference_only | review protocol |
| `safety.flash_pse_blocker.v1` | reference_only | safety guidance |
| `transition.dissolve.short_natural.v1` | validated | canonical 12-frame native dissolve |
| `typography.caption_guidance.v1` | reference_only | no typography emitter |
| `typography.readability.captions.v1` | reference_only | no typography emitter |

The validated/reference-only split is **4/11**. The source atlas remains a
retrieval map rather than a runtime network dependency.

## Living Still v2 implementation

The pinned model is Apple Core ML Depth Anything V2 Small FP16 at source
revision `cfef6f6f2a70783dedc0bfae40cecbc2052285d3`, Apache-2.0. The locator
hash-verifies the recorded source files and compiled metadata before loading.

At the default four-second/30 fps setting, the renderer calls Core ML once,
retains the FP16 field, processes it once, and reuses it across all 120 frames.
It records raw and processed depth identities, derives path-complete overscan,
encodes opaque video-only ProRes 422 HQ (`apch`, `yuv422p10le`), verifies
timing/codec/stream properties, and publishes at a deterministic content
address. A different or corrupt file at that address fails closed.

## Old Television v2 implementation

The closed typed FFmpeg graph implements a sustained CRT look: scanlines,
temporal noise, tube curvature/overscan, chroma shift, ghosting, bloom, jitter
and tracking disturbance, vignette, and continuous micro-flicker. Raw filter
arguments are not accepted. The graph emits no opacity channel; absolute luma
modulation is capped at two percent.

The adapter binds source, parameters, renderer version, and exact FFmpeg/
FFprobe identities into the recipe. It verifies the video-only ProRes output
before atomic publication and safely reuses only a matching existing artifact.

## Verification evidence

The active Living Still path is
`/Users/marcboyer/Movies/FCPCommandConsole/exports/bakeoff/v2-production-hq/living-still-v2`;
the active Old Television path is
`/Users/marcboyer/Movies/FCPCommandConsole/exports/bakeoff/v2-production/old-television-v2`.
Together they contain 10 representative sources through both effects: **20
accepted movies**, each 4.000 seconds, 30 fps, 120 frames, ProRes 422 HQ `apch`,
10-bit 4:2:2 `yuv422p10le`, and zero audio streams.

The independent audit passed both effects across all ten cases. Living Still's
final 0.90 depth-motion/0.030 push recipe retained sustained, restrained non-
global motion with no observed black-frame, fade-only, crop, tear, exposed-
canvas, or hole failure. The layered fixture's camera-removed horizontal span
was 1.806 pixels at frame 60 and 3.426 pixels at frame 119. Its exact duplicate
frames were head-only: 0.033 seconds in seven cases, 0.067 seconds in product
and layered-depth, and 0.100 seconds in low-contrast, with no later repeats. Old
Television retained monochrome treatment and scanlines through frame 119, 120
unique frames per movie, stable quarter-by-quarter source distance, readable
text/product detail, and approximately 1.431–3.490/255 global luma range.

Two returned FCPXML artifacts admit the shared connected rendered-movie layer:

| Parent | Operation | Returned SHA-256 |
| --- | --- | --- |
| still | `564186C4-F931-466D-ABDF-16980F9C11F4` | `26eb90634a82dbbe7dfc1150a7288c25dc972c973ef1bfce5181ac9af8a377de` |
| movie | `3DF48DA4-DF68-4692-ACAA-4A6F73D9DEC4` | `87c95fa47679788adbff8ac9854bdfa2b485c9acff0bc6c9abdcb573a2cb9bc7` |

The scope is Final Cut Pro 12.3 (450152), FCPXML 1.14, one 1920×1080
progressive, 30 fps, 120-frame, four-second, opaque video-only ProRes 422 HQ
child (`apch`, `yuv422p10le`) at lane 1. Other durations and aspect ratios are
preview-only and refused for project export. The tested still source was
1920×1080, unrotated, and had no intrinsic timing/audio; the tested movie source
was 1920×1080, identity-transform, progressive 30 fps CFR, eight seconds, and
audio-bearing. Each parent had a four-second spine/treatment extent. Runtime
admission binds the movie to 240 decoded frames and the exact observed single
untagged two-channel 48 kHz audio stream; orientation, transform, scan, cadence,
and audio-tuple drift fail closed. A returned round trip is construction
evidence, not effect-specific visual evidence or direct pixel editability.

## User-visible truth

- Preview and export use the same prepared movie for rendered effects.
- The original media remains unchanged; movie audio remains on the spine.
- Rendered parameters are adjustable by regenerating from the retained recipe,
  not by exposing fictitious native Final Cut controls.
- Missing models/tools, drifted source/recipe/artifact identities, or revoked
  semantic evidence clear/refuse the treatment.
- Opacity fade is not substituted when a v2 renderer is unavailable.

## Remaining limitations

- Natural Dissolve's current canonical 12-frame route still needs a fresh Final
  Cut import.
- Living Still's head-only 0.033–0.100 second startup hold remains an accepted
  but explicit temporal regression metric; low-contrast content remains subtle.
- The 20-movie bakeoff is representative formative engineering evidence, not
  expert or population perceptual validation and not a medical safety study.
- The returned artifacts are scoped to the tested Final Cut build and parent
  contexts; they do not admit arbitrary stacking or future versions.
- Installed-app resource parity must be rechecked after the final build. This
  source/runtime checkpoint does not prove an older installed bundle current.
