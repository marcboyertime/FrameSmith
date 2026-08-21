# FrameSmith status

## Current checkpoint — 2026-08-21

FrameSmith is the product name. Internal repository, package, bundle, and
legacy command identifiers remain stable for compatibility.

The director-control contract remains a tested runtime invariant. FrameSmith
may change treatment pixels and parameters, but it may not replace, omit,
duplicate, reorder, retime, slip, or move the user's media and edit points.
Rendered effects preserve that boundary by keeping the admitted source on the
spine and adding one full-duration video-only visual above it.

The strict technique catalog contains **15 provenance-bearing cards: 4
validated and 11 reference-only**. `motion.opacity.fade.v1` is deliberately
reference-only after retirement of the v1 Living Still opacity route. A card is
validated only when its implementation, representative visual review, and
construction evidence are all present.

## Production effects

| Effect | Production construction | Current evidence boundary |
| --- | --- | --- |
| Living Still v2 | one continuous Core ML depth field, rendered to a content-addressed video-only ProRes 422 HQ movie and connected above the unchanged still | 10-case visual bakeoff; exact shared preview/export movie; still-parent Final Cut 12.3 returned round trip |
| Targeted Rotate + Zoom | admitted native transform/rotation construction with a confirmed normalized target | existing native Phase 1 evidence |
| Natural Dissolve | canonical read-only 12-frame native transition | construction-tested; the current 12-frame route still needs a fresh Final Cut import |
| Old Television v2 | sustained typed CRT render, content-addressed as a video-only ProRes 422 HQ movie and connected above the unchanged still or movie | 10-case visual bakeoff; exact shared preview/export movie; still- and movie-parent Final Cut 12.3 returned round trips |

Living Still v2 and Old Television v2 are FrameSmith-regenerable baked
treatments. They are not native Final Cut parameter approximations and neither
uses an opacity fade.

## Living Still v2

Living Still v2 uses Apple's Core ML Depth Anything V2 Small FP16 model pinned
to revision `cfef6f6f2a70783dedc0bfae40cecbc2052285d3` under Apache-2.0.
Inference is local. The model locator descriptor-copies the hash-pinned source
package into a private directory, compiles that immutable snapshot, seals and
hashes the complete compiled tree, and verifies it before model load and after
prediction. The adjacent acquisition-time compiled cache is never trusted for
inference; missing, unsafe, changed, or path-swapped artifacts fail closed.

At the admitted default, one FP16 depth inference is reused across a four-second,
30 fps render—120 frames. The continuous warp records source, model, raw and
processed depth, recipe, runtime, codec, and movie identities. The output is a
deterministic content-addressed, opaque video-only ProRes 422 HQ file. Preview opens
that exact file and export checksum-verifies and copies it; export cannot render
a second version.

Live controls are duration, depth-motion strength, camera push, horizontal and
vertical drift, and depth smoothing. The 1920-pixel maximum long-edge ceiling,
model, method, source-preservation rule, and standalone frame-rate profile are
invariants. Final Cut receives baked pixels; parameter revision means
regeneration in FrameSmith.

## Old Television v2

Old Television v2 is a sustained CRT signal treatment across the complete
duration. Its typed renderer combines display-fixed scanlines, temporally
coherent analog noise, tube curvature with overscan, bounded chroma shift,
ghosting, phosphor bloom, micro-jitter and horizontal tracking disturbance,
vignette, and continuous micro-flicker. The luma modulation ceiling is two
percent and the rendered construction has no opacity channel, full-frame flash,
or fade approximation.

Live controls cover duration, CRT profile, overall intensity, component
strengths, flicker, and deterministic texture seed. The 1920-pixel maximum
long-edge ceiling, 30 fps, render method, and source preservation are
invariants. The movie source keeps its original audio on the spine because the
connected treatment itself is video-only.

## Production visual bakeoff

The active artifact paths are:

- Living Still:
  `/Users/marcboyer/Movies/FCPCommandConsole/exports/bakeoff/v2-production-hq/living-still-v2`
- Old Television:
  `/Users/marcboyer/Movies/FCPCommandConsole/exports/bakeoff/v2-production/old-television-v2`

Together they contain **10 representative inputs × both effects = 20 accepted
movies**, all four seconds, 30 fps, 120 frames, ProRes 422 HQ `apch`, 10-bit
4:2:2 `yuv422p10le`, with no audio in the rendered treatment. The cases cover
portrait hair, full-body thin limbs, an irregular organic subject,
architecture, text, crisp product edges, landscape depth, low contrast,
portrait orientation, and explicit layered depth. The aspect-preserving visual
matrix includes preview-only geometries; project export remains restricted to
the exact 1920×1080 profile below.

The independent audit passed both effects across all ten cases:

- Living Still retained motion in every quarter with genuine but restrained
  non-global depth. In the layered-depth case, camera-removed horizontal span
  reached 1.806 px at frame 60 and 3.426 px at frame 119; the camera-only
  residual was 0.320576/255, or 12.0549 percent of start-to-end RGB MAE. The
  counterfactual is diagnostic and accounts for Core Image's bottom-left/+Y-up
  coordinates versus PNG/Pillow's top-left/+Y-down coordinates; it is not pure
  depth amplitude because Pillow bicubic differs from Core Image and the
  decoded codecs differ. The flat-component span is the stronger relative-
  motion evidence. No black-frame, fade-only, crop, tear, or exposed-hole
  failure was observed. Exact duplicate
  frames were confined to the head: 0.033 seconds in seven cases, 0.067 seconds
  in product and layered-depth, and 0.100 seconds in low-contrast; no later
  duplicates were found. Low-contrast motion is intentionally subtle.
- Old Television retained monochrome treatment and horizontal scanlines at
  frames 0, 60, and 119, with 120 unique frames in every movie and stable
  source-distance measurements across all four quarters. Text and product
  details remained legible. Observed global luma range was approximately
  1.43–3.49 levels out of 255 and did not dominate the sustained CRT texture.

Evidence maps, contact sheets, crops, and metrics are under
`v2-production/review/qa-v2`,
`v2-production/review/final-independent-audit-20260808`, and
`v2-production/review/final-hq-independent-audit-20260808`.
This is representative visual verification at the recorded defaults, not an
expert-preference study, population evidence, or proof of every legal setting.

## Exact preview/export and Final Cut evidence

Both rendered effects cross preview/export through one sealed artifact carrying
its SHA-256, construction/recipe digests, source identity, geometry, timing,
codec, pixel format, and video-only contract. A changed recipe or source mints a
new construction identity. Missing or drifted bytes refuse export.

Two hardened FCPXML 1.14 probes passed in the isolated Final Cut Pro **12.3
(450152)** copy:

| Parent context | Operation | Returned FCPXML SHA-256 |
| --- | --- | --- |
| still | `564186C4-F931-466D-ABDF-16980F9C11F4` | `26eb90634a82dbbe7dfc1150a7288c25dc972c973ef1bfce5181ac9af8a377de` |
| movie | `3DF48DA4-DF68-4692-ACAA-4A6F73D9DEC4` | `87c95fa47679788adbff8ac9854bdfa2b485c9acff0bc6c9abdcb573a2cb9bc7` |

The returns admit one opaque, full-duration, video-only ProRes 422 HQ movie
(`apch`, `yuv422p10le`) as a lane-1 visual above the tested parent kinds. The
admitted surface is exactly FCPXML 1.14, 1920×1080 progressive, 30 fps, 120
frames, and four seconds. Arbitrary duration or aspect-ratio renders are
preview-only and refused for project export. The still fixture used a
1920×1080 unrotated, timing-free, audio-free source resource; its spine video
and treatment were both four seconds. The movie fixture used a 1920×1080,
identity-transform, progressive 30 fps CFR, eight-second source; its spine
asset-clip and treatment were both four seconds, with source audio retained.
Runtime admission binds that movie context to 240 decoded frames and the exact
observed single untagged two-channel 48 kHz audio stream. Orientation,
transform, scan, cadence, and audio-tuple drift now fail closed.
The returns do not establish direct editability of rendered pixels, arbitrary
layering, or another Final Cut version.

## Installed app verification — 2026-08-21

The release build is installed at
`/Users/marcboyer/Applications/FrameSmith.app`. Its ad-hoc signature, bundle ID
`com.marcboyer.FCPCommandConsole`, icon, 15 technique cards, registry, model
manifest, and schemas were verified against this checkout. The complete Swift
suite passed **379 tests with zero failures**, and the strict catalog audit
passed with 4 validated and 11 reference-only cards.

The installed app completed both rendered workflows against the admitted
1920×1080 still fixture. Living Still produced and exported SHA-256
`228c3671d5ac09d943392c466a6219d144de03ff6ceb9babfa98929dfa65856c`
under operation `F1E67F22-C1B8-4C06-9A92-533289AB77B0`; Old Television
produced and exported SHA-256
`202570297d8a54c1c10006e7f5222929bf8ccd25e607f4e62585e031ce517b15`
under operation `E67C7CCE-1BA5-4878-975B-CBF1F58172D5`. Both package movies
are one video-only 1920×1080 ProRes 422 HQ `apch` stream at 30 fps, 120 decoded
frames, and exactly four seconds, and both FCPXML documents validate against
the installed 1.14 DTD.

This live pass also exercises the AVFoundation `AVPlayerLayer` preview bridge
that replaced the crashing private AVKit/SwiftUI representable. Living Still
no longer aborts when its exact preview appears; rendered treatment movies loop
for inspection and pause/detach during teardown. Screenshots are retained at
`/Users/marcboyer/Movies/FCPCommandConsole/provenance/installed-framesmith-living-still-v2-20260821.jpg`
and
`/Users/marcboyer/Movies/FCPCommandConsole/provenance/installed-framesmith-old-television-v2-20260821.jpg`.

## Output and runtime boundary

FrameSmith generates a **new** Final Cut project package. It does not inspect or
mutate an existing timeline, production library, or source file. An inert local
plan package remains different from a standalone FCPXML export and is not an
effect render or importability claim.

The shipped product contains no UI automation, AppleScript, Accessibility
control, timeline-selection inference, or production-library modification.
Development-time automation of the isolated Final Cut copy is permitted and is
how the returned evidence above was gathered.

## Remaining limitations and next work

- Fresh Final Cut evidence remains open for the canonical 12-frame Natural
  Dissolve route.
- Living Still's head-only 0.033–0.100 second startup hold is bounded and
  accepted for this pass, but should remain a temporal regression metric.
- The rendered effects are regenerable from retained recipes; their pixels are
  not natively editable inside Final Cut.
- The 20-movie bakeoff establishes representative behavior, not expert or
  population perceptual preference, medical safety certification, or every
  source/control combination.
- Re-run installed-app parity whenever the release binary or bundled resources
  change; the current pass is bound to the 2026-08-21 release build above.

See `docs/LIVING_STILL_V2_DESIGN.md`,
`docs/LIVING_STILL_V2_BAKEOFF.md`,
`docs/editorial-intelligence/BAKEOFF_AND_COVERAGE.md`, and
`docs/PARAMETER_LIVENESS.md` for the detailed boundaries.
