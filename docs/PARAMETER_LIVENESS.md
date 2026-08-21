# FrameSmith parameter liveness

Registry metadata is the source of truth for presentation and liveness. It is
decoded during registry load and consulted by plan validation, revision, the
inspector, treatment admission, and effect construction. A parameter existing
in JSON or source does not make it editable. Missing metadata fails closed as
unsupported/read-only.

## Living Still v2

Living Still v2 is a rendered effect. Its live controls are:

| Parameter | Range | Default |
| --- | ---: | ---: |
| `durationSeconds` | 0.1–30 s | 4 s |
| `motionStrength` | 0–1 | 0.90 |
| `pushIn` | 0–0.12 frame fraction | 0.030 |
| `panX` | -0.04–0.04 width fraction | 0.012 |
| `panY` | -0.04–0.04 height fraction | -0.006 |
| `depthSmoothing` | 0–1 | 0.35 |

`outputLongEdge=1920` is a fixed invariant/read-only maximum long-edge ceiling,
not a selectable export resolution. `fps=30`, the pinned model ID, continuous-
depth method, and `preserveOriginal=true` are also invariant/read-only. A live
revision creates a new content-addressed prepared movie. Preview and export
then use that exact SHA-256-bound movie. There are no native scale/opacity/color
keyframes and no fade parameter in Living Still v2.

The admitted project-export profile is narrower than preview liveness: exactly
1920×1080, 30 fps, 120 frames, four seconds, video-only ProRes 422 HQ (`apch`,
`yuv422p10le`), FCPXML 1.14, and Final Cut 12.3 (450152). Other duration/aspect
renders may be previewed but are refused for project export.

The pinned model is Apple Core ML Depth Anything V2 Small FP16 at revision
`cfef6f6f2a70783dedc0bfae40cecbc2052285d3` (Apache-2.0). Model or source
identity drift refuses construction rather than exposing a degraded fallback.

## Targeted Rotate + Zoom

Targeted Rotate + Zoom remains live for duration, start/end scale, and signed
start/end rotation. Positive Final Cut rotation is counterclockwise;
`direction` is derived compatibility metadata, not a direct control. A confirmed
normalized focal point is typed execution input rather than an invented
parameter. Quantized movie duration beyond admitted source duration is refused.

## Natural Dissolve

Natural Dissolve has a production native emitter, but its canonical 12-frame
duration and other construction values remain unsupported/read-only in the
generic parameter editor. The emitter refuses insufficient handles rather than
moving an edit point or shortening the transition. The current 12-frame route
has construction evidence and still needs a fresh Final Cut import.

## Old Television v2

Old Television v2 is a rendered effect. Its live controls are:

| Parameter | Range/default |
| --- | --- |
| `durationSeconds` | 0.1–30 s; default 4 s |
| `profile` | `broadcast-mono` or `color-crt`; default `broadcast-mono` |
| `intensity` | 0–1; default 0.68 |
| `scanlineStrength` | 0–1; default 0.42 |
| `noiseStrength` | 0–1; default 0.28 |
| `syncInstability` | 0–1; default 0.22 |
| `chromaSeparation` | 0–1; default 0.18 |
| `bloomStrength` | 0–1; default 0.20 |
| `vignetteStrength` | 0–1; default 0.34 |
| `ghostingStrength` | 0–1; default 0.10 |
| `flickerStrength` | 0–1; default 0.12 |
| `seed` | 0–2147483647; default 7341 |

`outputLongEdge=1920` is a fixed invariant/read-only maximum long-edge ceiling,
not a selectable export resolution. `fps=30`, `renderMethod=ffmpeg-crt-v2`, and
`preserveOriginal=true` are also invariant/read-only. Every request is typed
and bounded; raw FFmpeg filter arguments are never a user-editable surface. The
renderer produces a content-addressed, video-only ProRes 422 HQ movie. It has no
opacity channel or fade event, and its continuous luma modulation is capped at
two percent.

Project export uses the same exact admitted profile as Living Still: 1920×1080,
30 fps, 120 frames, four seconds, video-only ProRes 422 HQ (`apch`,
`yuv422p10le`), FCPXML 1.14, and Final Cut 12.3 (450152). Other duration/aspect
renders remain preview-only and are refused for project export.

Rendered controls are FrameSmith-regenerable, not native Final Cut effect
parameters. The source clip remains on the spine; a movie source keeps its
audio below the connected visual treatment.

## Standalone opacity fade

`motion.opacity.fade.v1` remains `reference_only`. Its former Living Still v1
association is retired, `implemented=false`, and it is not used as a fallback
for Living Still v2 or Old Television v2.
