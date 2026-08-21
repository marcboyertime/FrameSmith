# FrameSmith

FrameSmith is the product name. Internal repository, package, bundle, and
legacy command identifiers remain stable for compatibility. Phase 1 is
complete; current work extends its evidence discipline to quality-first
rendered effects.

It is a real local SwiftUI macOS app for turning admitted stills or movies and
a creative instruction into a schema-versioned FrameSmith plan. It admits media
read-only with source identities, plans against the local registry, offers a
plan-revision inspector, and can generate a **new** Final Cut project package.
It never inspects or mutates an existing Final Cut timeline.

All four effects—Living Still, Targeted Rotate + Zoom, Natural Dissolve, and
Old Television—have production standalone emitters. Living Still v2 and Old
Television v2 use the shared rendered-effect path: the unchanged source stays
on the spine, one opaque video-only ProRes 422 HQ treatment movie is connected
above it, and preview/export consume the exact same SHA-256-bound file.

Rendered comparison is artifact-backed. Each A/B/C option prepares and admits
its own exact movie, and all selected tiles resolve one shared integer frame
index. A rendered tile never substitutes neutral native channels, an untreated
poster, or stale pixels; missing or drifted bytes are shown as a refusal with a
retry path. Native options continue to use their exact admitted channels.

Export is a strict second phase. It accepts either a native construction or an
already prepared rendered artifact; the export builder has no render fallback.
The installed app previews the prepared asset and passes those exact
checksum-verified bytes to project export. Continuous slider changes remain
local drafts and create one authoritative revision and render request when the
gesture commits.

Living Still v2 runs one local inference with Apple's Core ML Depth Anything V2
Small FP16 model pinned to revision
`cfef6f6f2a70783dedc0bfae40cecbc2052285d3` (Apache-2.0), then reuses the
continuous depth field across the complete render. The final `0.90` depth-
motion/`0.030` push recipe passed all ten independent HQ visual and stream
checks; its non-global depth is genuine but deliberately restrained, with
low-contrast material remaining subtle. Old Television v2 is a sustained CRT
treatment: scanlines, temporal noise, curvature/overscan, chroma shift,
ghosting, bloom, jitter/tracking, vignette, and micro-flicker capped at two
percent. Neither effect is a native transform/base-recipe approximation or an
opacity fade.

The active production evidence contains 20 four-second, 30 fps HQ movies—10
representative sources through each effect. Living Still's final movies are
under `v2-production-hq/living-still-v2`; Old Television's are under
`v2-production/old-television-v2`. Hardened Final Cut Pro 12.3 round trips
returned the connected rendered-movie construction over both a still and a
movie. The current canonical read-only 12-frame Natural Dissolve route remains
separately construction-tested and still needs its own fresh Final Cut import.

The inspector exposes only registry-declared live controls. It distinguishes
runtime edits from invariant and unsupported values, validates revisions
atomically, and supports reset/reset-all to the plan baseline. Living Still v2
exposes duration, depth motion, push, two-axis drift, and depth smoothing. Old
Television v2 exposes its typed profile, intensity, component strengths,
flicker, duration, and deterministic texture seed. Editing those values creates
a new retained recipe and prepared movie; baked pixels are regenerable in
FrameSmith, not directly editable as native effect parameters in Final Cut.

## Build and verify

```sh
swift test
make test
swift build -c release
make install-app
make launch-app
```

The strict catalog currently contains 15 cards: 4 validated and 11 reference-
only. The
standalone opacity-fade card remains reference-only after retirement of the v1
Living Still route. Installing or launching an app is a separate local-artifact
step, not proof that a previous installed copy is current.

## Outputs and evidence boundary

`Save Local Plan Package` writes an inert, byte-verified package under
`~/Movies/FCPCommandConsole/exports/local-plan-packages/` by default. It copies
admitted media and plan/provenance metadata, but it is not FCPXML, not an effect
render, and is not claimed importable by Final Cut.

Standalone FCPXML export is different: after registry validation, admitted
local-media checks, emitter availability, and the version-scoped Final Cut
semantic profile, it stages and publishes a new project package. The profile is
specific to Final Cut 12.3 (build 450152); evidence remains bounded to the
admitted constructions. The returned still-parent FCPXML SHA-256 is
`26eb90634a82dbbe7dfc1150a7288c25dc972c973ef1bfce5181ac9af8a377de`;
the movie-parent return is
`87c95fa47679788adbff8ac9854bdfa2b485c9acff0bc6c9abdcb573a2cb9bc7`.
Those artifacts do not establish broad visual quality, direct editability of
rendered pixels, every control combination, or compatibility with future Final
Cut versions.

Rendered project export is further restricted to FCPXML 1.14 with one
1920×1080, 30 fps, 120-frame, four-second, video-only ProRes 422 HQ movie
(`apch`, `yuv422p10le`). Arbitrary duration/aspect renders are preview-only and
refused for project export. Returned construction evidence is parent-specific:
the tested still source was 1920×1080 with no intrinsic timing or audio; the
tested movie source was 1920×1080, identity-transform, progressive 30 fps CFR,
eight seconds, and audio-bearing. Both used a four-second spine/treatment
extent. Runtime admission now binds those facts to one immutable source-byte
snapshot and requires one video track (240 decoded frames) plus the exact
observed single untagged two-channel 48 kHz audio stream. Rotated stills,
transformed/interlaced/VFR movies, and audio-layout drift are refused.

See [STATUS.md](STATUS.md), [docs/PARAMETER_LIVENESS.md](docs/PARAMETER_LIVENESS.md),
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), and
[docs/ADMITTED_PREVIEW_ARTIFACT_LIFECYCLE.md](docs/ADMITTED_PREVIEW_ARTIFACT_LIFECYCLE.md),
and [docs/POST_PHASE1_ROADMAP.md](docs/POST_PHASE1_ROADMAP.md).
