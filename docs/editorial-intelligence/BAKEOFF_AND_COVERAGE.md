# Representative bakeoff and coverage

Recorded 2026-08-08 for FrameSmith's current rendered-effect construction and
Final Cut Pro **12.3 (450152)**.

## Current coverage boundary

The rendered treatment path now covers Living Still v2 and Old Television v2.
Both are validated. They preserve the director's source on the spine and
connect one opaque, video-only ProRes 422 HQ treatment movie above it; preview
and export share that exact prepared movie.

`motion.opacity.fade.v1` is intentionally `reference_only`. The retired native
Living Still/opacity route and the retired native Old Television base recipe are
not implementations or fallbacks for the v2 cards.

Treatment retrieval remains fail-closed:

| Situation | Result |
| --- | --- |
| One admitted still, Living Still renderer and pinned model available | Living Still v2 may be offered when its exact construction and project-export scope gates pass |
| One admitted still or movie, CRT renderer available | Old Television v2 may be offered when its prerequisites and flash-risk gates pass |
| Confirmed focal target and targeted native capability | Targeted Rotate + Zoom may also be considered |
| Two adjacent clips with sufficient handles | Canonical Natural Dissolve may be considered |
| Missing model/tool, drifted identity, failed render verification, or revoked semantic profile | the affected rendered treatment is refused rather than approximated |

The generator may return fewer than three options. Labels, parameter-only
variation, or a retired fade do not count as semantic diversity.

## Production rendered matrix

The active production paths are:

- Living Still:
  `/Users/marcboyer/Movies/FCPCommandConsole/exports/bakeoff/v2-production-hq/living-still-v2`
- Old Television:
  `/Users/marcboyer/Movies/FCPCommandConsole/exports/bakeoff/v2-production/old-television-v2`

Together they contain **10 representative cases × both effects = 20 accepted
HQ movies**. Every movie is four seconds at 30 fps (120 frames), ProRes 422 HQ
`apch`, `yuv422p10le`, and video-only. The cases cover:

1. close portrait and hair detail;
2. full body, hands, and thin limbs;
3. animal or irregular organic structure;
4. architecture and straight-line grids;
5. text and signage;
6. crisp product edges;
7. landscape depth;
8. low contrast;
9. portrait orientation; and
10. explicit layered depth.

The final Living file/source/SHA-256 map, contact sheets, edge crops, verdict,
and metrics are under
`v2-production/review/final-hq-independent-audit-20260808/`. The Old Television
mapping and temporal metrics remain under `v2-production/review/qa-v2/` and
`v2-production/review/final-independent-audit-20260808/`.

## Living Still v2 judgment

Living Still v2 uses Apple's Core ML Depth Anything V2 Small FP16 model pinned
to revision `cfef6f6f2a70783dedc0bfae40cecbc2052285d3` under Apache-2.0.
Each four-second render performs one depth inference and reuses the resulting
continuous field across all 120 frames.

The review screened hair, shoulders, faces, hands, text, architecture,
low-contrast regions, portrait orientation, borders, and temporal motion for:

- haloing, binary layer seams, duplicated strips, or exposed borders;
- rubber-sheet deformation and depth inversion;
- aspect, orientation, gamma, or color drift; and
- unstable frame-to-frame sampling.

The final HQ matrix passed all ten visual and stream checks. Dense temporal,
native-frame, center, edge, and corner review found sustained motion without
black/frozen clips, exposed canvas, tearing, holes, egregious warping, crop
failure, or illegible text/product detail.

The treatment is restrained and professional rather than dramatic 3D. Global
push/pan remains visually important and low-contrast motion remains subtle. In
the layered fixture, removing the exact global camera transform leaves a direct
horizontal component span of 1.806 pixels at frame 60 and 3.426 pixels at frame
119. The camera-only image diagnostic leaves 0.320576/255 RGB MAE at frame 119,
or 12.0549 percent of start-to-end MAE. That residual is diagnostic rather than
pure depth amplitude because Pillow bicubic is not Core Image and decoded
codecs differ; the flat-component centroid span is the stronger non-global
motion evidence.

Exact duplicate frames were head-only: 0.033 seconds in seven cases, 0.067
seconds in product and layered-depth, and 0.100 seconds in low-contrast. No later
duplicates occurred. The text-signage border proxy's 0.009098 peak was sparse
black source text/grid moving under the push/pan, not exposed canvas. These
bounded findings remain regression signals rather than hidden limitations.

## Old Television v2 judgment

Old Television v2 is a sustained CRT treatment, not an entrance/exit animation
and never a fade approximation. Across the complete movie it combines:

- display-fixed scanlines;
- temporally coherent analog noise;
- mild tube curvature with proportional overscan;
- bounded chroma separation;
- light signal ghosting and phosphor bloom;
- micro-jitter and bounded horizontal tracking disturbance;
- tube-edge vignette; and
- continuous micro-flicker whose absolute luma amplitude is capped at two
  percent.

The review screened persistence across time, face/text readability, black
corners and border flashes, tracking distortion, digital-looking RGB speckle,
and full-frame opacity events. The admitted defaults passed the ten-case
representative screen. The safety result is construction-level and bounded: the
typed graph emits no opacity channel and enforces the two-percent ceiling. It
is not medical certification or a population response study.

The independent audit found 120 unique frames in every Old Television movie.
Monochrome treatment and horizontal scanlines remained present at frames 0, 60,
and 119; source-distance measurements stayed stable across all four quarters;
and the observed global luma range was approximately 1.43–3.49 levels out of
255, visually subordinate to the sustained CRT texture. No CRT dropout was
observed, and the text/signage and crisp-product cases remained legible.

## Exact preview/export parity

Rendered effects use a sealed `RenderedEffectAsset`. Its source SHA-256,
construction digest, renderer recipe digest, dimensions, frame count, duration,
codec, pixel format, video-only flag, and movie SHA-256 are verified before
use. Preview reads that exact file. Export verifies and copies that exact file;
it cannot render a replacement.

Project export is scoped to one exact movie contract: 1920×1080, 30 fps, 120
frames, four seconds, ProRes 422 HQ (`apch`, `yuv422p10le`), video-only. Other
duration/aspect renders are preview-only and refused for project export.

Consequently parity here means byte identity at the visible treatment boundary,
not a claim that two independent renderers happened to look similar.

## Final Cut round trips

Two hardened probes exercised the shared connected rendered-movie construction
with different spine-parent kinds:

| Parent context | Operation | Returned FCPXML SHA-256 | Result |
| --- | --- | --- | --- |
| still | `564186C4-F931-466D-ABDF-16980F9C11F4` | `26eb90634a82dbbe7dfc1150a7288c25dc972c973ef1bfce5181ac9af8a377de` | passed |
| movie | `3DF48DA4-DF68-4692-ACAA-4A6F73D9DEC4` | `87c95fa47679788adbff8ac9854bdfa2b485c9acff0bc6c9abdcb573a2cb9bc7` | passed |

Both returns are scoped to Final Cut Pro 12.3 (450152), FCPXML 1.14. The test
movie was opaque, 1920×1080, 30 fps, 120 frames, four seconds, video-only ProRes
422 HQ (`apch`, `yuv422p10le`). In the movie-parent case,
the unchanged source retained its original audio below the visual treatment.
The still source resource was 1920×1080, unrotated, and had no intrinsic
timing/audio; its spine video was four seconds. The movie source resource was
1920×1080, identity-transform, progressive 30 fps CFR, eight seconds, and
audio-bearing; its spine asset-clip was four seconds. Runtime admission binds
that context to 240 decoded frames and the exact observed single untagged
two-channel 48 kHz audio stream. Orientation, transform, scan, cadence, and
audio-tuple drift are typed and refused.

These returns admit the still and movie parent contexts for the current shared
construction. They do not prove direct Final Cut editability of baked pixels,
future-version compatibility, arbitrary connected layers, or the visual quality
of an effect not covered by its own bakeoff.

## Bounded conclusion

The evidence currently supports:

- representative visual verification of Living Still v2 and Old Television v2
  at their recorded defaults;
- exact ProRes 422 HQ `apch` stream verification for all 20 accepted treatment
  movies;
- deterministic/content-addressed rendered artifacts and fail-closed drift
  handling;
- exact preview/export movie parity;
- unchanged source placement, including source audio for a movie parent; and
- still- and movie-parent Final Cut 12.3 round-trip admission for the connected
  rendered-movie layer.

It does **not** establish expert or population perceptual preference, medical
safety certification, native pixel editability, every parameter combination,
or compatibility beyond the tested Final Cut build.
