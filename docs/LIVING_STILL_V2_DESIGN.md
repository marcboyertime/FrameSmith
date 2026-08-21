# Living Still v2 — continuous depth render

Status: **implemented and validated. The final ProRes 422 HQ/apch matrix passed
all ten independent visual and stream checks.** The shared still-parent
rendered-movie construction is separately admitted in Final Cut Pro 12.3
(450152).

This document supersedes the earlier two-plane native-layer proposal. That
proposal optimized for direct Final Cut editability before its subject matte
had been inspected. The representative bakeoff found a hard silhouette and
hair fringe on organic subjects, so the design now follows the repository's
quality-first rule: use a continuous depth warp, retain the complete recipe,
and expose honest FrameSmith regeneration instead of shipping a weaker native
approximation.

## Product decision

Living Still v2 is a locally rendered depth-aware camera move. It is not:

- the retired v1 scale/pan/color construction;
- a binary foreground cutout or two-plane cardboard layer;
- a native Final Cut transform;
- an opacity fade; or
- a separately computed preview.

The source still remains unchanged on the Final Cut spine. One opaque,
video-only ProRes 422 HQ treatment movie (`apch`, `yuv422p10le`) is connected
above it for the admitted export profile. The app previews that exact SHA-256-
identified file, and export copies that same file; export is not allowed to
render a second version.

## Pinned depth dependency

| Field | Value |
| --- | --- |
| Provider | Apple |
| Model | Depth Anything V2 Small, Core ML FP16 |
| Identifier | `apple.coreml.depth-anything-v2-small-f16` |
| Source revision | `cfef6f6f2a70783dedc0bfae40cecbc2052285d3` |
| License | Apache-2.0 |
| Runtime | local Core ML; source media is not uploaded |
| Registry record | `registry/models/depth-anything-v2-small.json` |

Acquisition is explicit through `Scripts/acquire-depth-model`. The locator
verifies the pinned source files before it trusts the compiled model cache.
Missing files, unsafe filesystem entries, source-hash drift, invalid compiled
metadata, or model-load failure all refuse the render.

## Construction

```text
admitted still + exact SHA-256
        |
        v
pinned Apple Core ML model
        |
        +-- one FP16 relative-depth inference
        |
        v
deterministic edge-preserving depth processing
        |
        +-- one continuous field reused across every frame
        |
        v
restrained overscanned camera path + depth-aware warp
        |
        v
content-addressed, video-only ProRes 422 HQ movie
        |
        +-- preview reads this exact movie
        +-- export copies this exact movie
        v
lane-1 connected visual above unchanged still spine
```

The project-export profile is exactly 1920×1080, four seconds at 30 fps: 120
frames from one depth inference. The renderer does not call the model once per frame. It
keeps the admitted FP16 field alive, smooths it once, records raw and processed
depth digests, and reuses the field for the complete render.

The content address binds the source identity, model revision and source-file
hashes, compiled model identity, raw and processed depth-field identities,
renderer version, camera recipe, codec, and pixel format. A verified artifact
already present at that address is reused. A different or corrupt occupant is
never overwritten or silently accepted.

## Live controls

| Control | Admitted range | Default |
| --- | ---: | ---: |
| duration | 0.1–30 s | 4 s |
| depth motion | 0–1 | 0.90 |
| camera push | 0–0.12 frame fraction | 0.030 |
| horizontal drift | -0.04–0.04 width fraction | 0.012 |
| vertical drift | -0.04–0.04 height fraction | -0.006 |
| depth smoothing | 0–1 | 0.35 |

The model ID, method, 30 fps standalone profile, fixed 1920-pixel maximum
long-edge ceiling, and source-preservation rule are invariants. Editing a live
control creates a new recipe and therefore a new prepared artifact; it does not
mutate pixels in place inside Final Cut. Controls outside the exact four-second,
1920×1080 project profile may be previewed, but project export refuses arbitrary
duration or aspect until separately admitted.

The 0.90 depth-motion/0.030 push defaults were selected from a controlled
candidate comparison. Direct visual review selected them as the strongest
artifact-free candidate while reducing the global push from the earlier 4.5
percent recipe. The final HQ matrix reproduced the candidate and passed its
complete ten-case gate.

## Quality boundaries

The renderer bounds depth displacement, derives overscan from the complete
camera path, clamps extreme relative depth, and verifies the encoded movie
before publication. The visual vetoes remain:

- haloing, duplicated edge strips, or exposed borders;
- rubber-sheet faces, hands, text, or architecture;
- depth inversion;
- orientation, aspect, gamma, or color drift; and
- unstable temporal sampling.

The evidence state is recorded in `docs/LIVING_STILL_V2_BAKEOFF.md`. Ten
representative sources produced the accepted four-second, 30 fps, ProRes 422 HQ
matrix under
`/Users/marcboyer/Movies/FCPCommandConsole/exports/bakeoff/v2-production-hq/living-still-v2`.
All ten passed independent visual, stream, border, and temporal review. The
result is professional and restrained rather than dramatic 3D; global push/pan
remains important, and highly uniform/low-contrast content reads subtly.

## Final Cut boundary

The hardened still-parent probe returned from Final Cut Pro 12.3 with FCPXML
SHA-256:

`26eb90634a82dbbe7dfc1150a7288c25dc972c973ef1bfce5181ac9af8a377de`

That admits the scoped 1920×1080, 30 fps, 120-frame, four-second, video-only
ProRes 422 HQ connected rendered-movie construction over a still for FCPXML
1.14 and the current semantic profile. The tested parent source was a
1920×1080 still with no intrinsic timing or audio; its spine video and connected
treatment were both four seconds. The construction probe and final HQ visual
matrix are separate evidence classes; both now pass within their recorded
scopes. The probe does not make rendered pixels natively editable or establish
compatibility with future Final Cut versions.

## Rejected alternative

Apple Vision foreground masks remain useful for subject selection and
crisp-edged graphics. They were rejected as Living Still's default compositor
because the inspected portrait matte removed flyaway hair and carried a visible
edge fringe. A two-plane construction would turn that limitation into a moving
seam. Continuous depth avoids the binary seam structurally, and the production
bakeoff then tested the different risks introduced by a depth warp.

The earlier native v1 route is historical evidence only. In particular,
`motion.opacity.fade.v1` remains `reference_only`; it is not a Living Still v2
backend or fallback.
