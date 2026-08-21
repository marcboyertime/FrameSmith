# Living Still v2 — production bakeoff and decision

Status: **Candidate C selected, implemented, and accepted. The final ProRes 422
HQ/apch matrix passed all ten independent visual and stream checks.** The shared
still-parent HQ rendered-movie construction is separately admitted in Final Cut
12.3.

Recorded 2026-08-08. Final Living Still runtime artifacts remain outside git
under `/Users/marcboyer/Movies/FCPCommandConsole/exports/bakeoff/v2-production-hq`.

## Decision

The default is a continuous Core ML depth warp rendered to a checksum-bound,
video-only ProRes 422 HQ movie. The earlier Vision two-plane proposal is demoted: its
portrait matte removed flyaway hair and introduced an edge fringe, creating the
exact moving seam that the effect must avoid. Direct Final Cut editability did
not justify that visual ceiling.

| Candidate | Result |
| --- | --- |
| A — historical native push/pan/fade | control only; not a Living Still v2 backend or fallback |
| B — Vision two-plane native layers | rejected as the default because organic subjects expose a hard-silhouette seam and halo risk |
| C — continuous Core ML depth warp | selected and validated at `motionStrength=0.90`, `pushIn=0.030` |
| D — Vision-edge/depth hybrid | not selected because it inherits B's failure at the subject boundary |

This replaces the old editability-first decision. Living Still v2 is
FrameSmith-regenerable baked output, not a native Final Cut transform and not an
opacity fade. The independent opacity technique card remains `reference_only`.

## Selected production construction

- Pinned model: Apple Core ML Depth Anything V2 Small FP16.
- Exact source revision:
  `cfef6f6f2a70783dedc0bfae40cecbc2052285d3`.
- License: Apache-2.0.
- Privacy: local Core ML inference; no media upload.
- Default timing: four seconds at 30 fps, exactly 120 frames.
- Selected motion recipe: depth-motion strength 0.90 and global push 0.030
  (three percent), with the existing two-axis drift and smoothing defaults.
- Inference count: one FP16 depth inference per source/recipe, reused across all
  120 frames.
- Project-export output: deterministic content-addressed, opaque video-only
  ProRes 422 HQ (`apch`, `yuv422p10le`), exactly 1920×1080, 30 fps, 120 frames,
  and four seconds.
- Placement: one full-duration lane-1 rendered movie above the unchanged still
  spine.
- Parity: preview opens the exact prepared movie that export checksum-verifies
  and copies. Export never computes a second render.

Other duration/aspect combinations may be rendered for preview experiments,
but project export refuses them until separately admitted.

The artifact identity records source, pinned model files and compiled identity,
raw and processed depth fields, renderer/runtime identity, recipe, codec, and
pixel format. A verified movie at the same address is reused; drift or a
different occupant fails closed.

The selected recipe came from a controlled comparison against the earlier
0.55/0.045 default and a 0.75/0.035 candidate. The winning 0.90/0.030 candidate
was the strongest tested artifact-free option while the global push fell from
4.5 to 3.0 percent. The final HQ encode reproduced the layered candidate's
camera-removed frame-119 component span within 0.052 pixels.

## Production matrix

The active production evidence contains **10 representative inputs × 2 rendered
effects = 20 accepted HQ movies**. Every movie is four seconds at 30 fps. The
final Living Still files are under `v2-production-hq/living-still-v2`; the Old
Television files remain under `v2-production/old-television-v2`.

| # | Representative case | Living Still evidence |
| ---: | --- | --- |
| 1 | close portrait / hair detail | `living-still-depth-aeafd395150f29caff2c33667eb43c1b.mov` |
| 2 | full body / hands / thin limbs | `living-still-depth-a7dcb56e6b825ab105201700be4bf1a9.mov` |
| 3 | animal / irregular organic subject | `living-still-depth-fa718b6625ae0ffc260032b71fcf4b89.mov` |
| 4 | architecture / grid | `living-still-depth-3a885449e4222199780a7689470d326d.mov` |
| 5 | text / signage | `living-still-depth-06e7444efff850e0327443b9ead5ab12.mov` |
| 6 | crisp product edges | `living-still-depth-7a67bc977ab73d3442556e680e9b391f.mov` |
| 7 | landscape with depth | `living-still-depth-95cfa3e7f649e7b1af824c81683add18.mov` |
| 8 | low contrast | `living-still-depth-e3bde6e2071ca19a7fa58b083532eec3.mov` |
| 9 | portrait orientation | `living-still-depth-e79af3e9b98b6e2f2ca471e411dafe01.mov` |
| 10 | layered depth | `living-still-depth-958a7806c287409b693d1fac78d091d9.mov` |

The exact final file-to-source/SHA-256 mapping is preserved in
`v2-production/review/final-hq-independent-audit-20260808/file-map.tsv`.
Multi-time contact sheets, native edge/corner crops, and final metrics are in
that audit directory.

## Visual gate

The representative review covered the complete ten-case set and the temporal
path rather than a single poster frame. It screened the hard vetoes established
before implementation:

- foreground halos and binary layer seams;
- exposed holes, black borders, or duplicated edge strips;
- rubber-sheet faces, hands, bodies, text, or architecture;
- depth inversion;
- unstable frame-to-frame sampling; and
- orientation, aspect, gamma, or color drift.

The final HQ matrix passed all ten representative visual and stream checks. All
movies decoded as ProRes 422 HQ `apch`, `yuv422p10le`, 30 fps, 120 frames,
4.000 seconds, and video-only. Dense temporal, native-frame, center, edge, and
corner review found sustained motion without black/frozen clips, exposed canvas,
tearing, holes, egregious warping, crop failure, or illegible text/product
detail.

The result is restrained professional depth rather than dramatic 3D. Global
push/pan remains visually important and low-contrast motion is deliberately
subtle. The layered fixture nevertheless directly demonstrates non-global
separation after removing the exact global camera transform: the four colored
components span 1.806 pixels horizontally at frame 60 and 3.426 pixels at frame
119, 37.45 percent stronger at frame 119 than the earlier production recipe.
The independent camera-only image diagnostic leaves 0.320576/255 RGB MAE at
frame 119, or 12.0549 percent of start-to-end MAE. That residual is diagnostic,
not pure depth amplitude, because Pillow bicubic is not Core Image and the
decoded codecs differ; the flat-component centroid span is the stronger
relative-motion evidence.

One minor limitation is preserved rather than hidden: exact duplicate frames
were confined to the head—0.033 seconds in seven cases, 0.067 seconds in
product and layered-depth, and 0.100 seconds in low-contrast—before continuous
motion. No later exact duplicates were found. This bounded smootherstep
quantization remains a useful regression signal.

The text-signage border proxy peaked at 0.009098 (0.91 percent) at frame 80.
Native edge strips establish that the pixels are sparse black source letters
and grid moving under the push/pan, not a contiguous strip or exposed canvas.
The final verdict and machine-readable metrics are in
`review/final-hq-independent-audit-20260808/FINAL_REPORT.md` and its `metrics/`
directory.

## Preview/export and Final Cut evidence

Preview/export parity is exact at the artifact boundary: both consumers use one
prepared movie and bind its SHA-256. The Final Cut probe independently tested
the FCPXML construction that carries that movie above a still.

| Context | Operation | Returned FCPXML SHA-256 | Result |
| --- | --- | --- | --- |
| connected rendered movie over still | `564186C4-F931-466D-ABDF-16980F9C11F4` | `26eb90634a82dbbe7dfc1150a7288c25dc972c973ef1bfce5181ac9af8a377de` | passed on Final Cut Pro 12.3 (450152) |

The returned document admits only FCPXML 1.14 on Final Cut 12.3 (450152), with
one 1920×1080, 30 fps, 120-frame, four-second, opaque video-only ProRes 422 HQ
movie connected above a tested 1920×1080 timing-free, audio-free still source;
the spine video and treatment extents were both four seconds. Arbitrary
duration/aspect project export is refused. The probe does not make pixels native
or substitute for the separate effect-specific visual matrix; both evidence
classes now pass within their recorded scopes.

## Revisit conditions

Re-open the decision if a new model or compositor can materially improve the
representative matrix without weakening determinism, local privacy, provenance,
or exact preview/export parity. A future result also needs its own scoped Final
Cut admission if it changes the connected-layer construction. Native
editability alone is not enough to displace the current winner.
