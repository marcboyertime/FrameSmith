# Connected rendered movie admission pass

## Verdict

`connectedRenderedMovieLayer` is admitted for Final Cut Pro **12.3 (build
450152)**, using FCPXML **1.14**, only in the two contexts returned on
2026-08-08 (America/New_York): one connected rendered movie over a movie parent
and one over a still parent.

The read-only hardened verifier returned `pass` for **all 10 checks in each
package**. This admits the generated import-and-return construction described
below. It does not turn a four-second probe into a general connected-movie,
retiming, blend, or editability claim.

## Returned evidence

### Movie parent

- operation/package: `3DF48DA4-DF68-4692-ACAA-4A6F73D9DEC4`
- package root: `/Users/marcboyer/Movies/FCPCommandConsole/exports/connected-rendered-movie-probes/3DF48DA4-DF68-4692-ACAA-4A6F73D9DEC4`
- exact project: `FCPCommandConsole Connected Rendered Movie Over Movie Probe`
- parent: one spine `<asset-clip>` backed by `clip-a.mov`
- returned artifact SHA-256: `87c95fa47679788adbff8ac9854bdfa2b485c9acff0bc6c9abdcb573a2cb9bc7`
- source package media SHA-256: `cd44c0c9565c8231ec421541f4a4877f340eae7db5129fb46ffa14f0bf871444`
- rendered package media SHA-256: `2b3dbb260adb5827badb219abc305dec96b435fb7cdefaf322abf2b7916f1c6c`
- source FCPXML SHA-256: `a6ecb33ec6490606c951b82546557fed06c42c6240ed6574c27aaa116ed355bf`
- rendered recipe digest: `cff38cbc3d76209224008c2a25bddf2e3d516de7280451d8432af56f4dfbb6d4`

### Still parent

- operation/package: `564186C4-F931-466D-ABDF-16980F9C11F4`
- package root: `/Users/marcboyer/Movies/FCPCommandConsole/exports/connected-rendered-movie-probes/564186C4-F931-466D-ABDF-16980F9C11F4`
- exact project: `FCPCommandConsole Connected Rendered Movie Over Still Probe`
- parent: one spine `<video>` backed by `living-still.png`
- returned artifact SHA-256: `26eb90634a82dbbe7dfc1150a7288c25dc972c973ef1bfce5181ac9af8a377de`
- source package media SHA-256: `170df5348f53221de630c7d7b385e6189f53a27baa2f2246ec7df4f379ed2567`
- rendered package media SHA-256: `a1a94b56c36d6a7c4f2568643c05bd8b713bdc6e6b56d62daa403d6a579d5c69`
- source FCPXML SHA-256: `bdd41fc63d69dc1384c4e95ada90f6e423e4c36aaf87b524042e479649043b12`
- rendered recipe digest: `91c9bb399d65c062cef11c1e26a97d52366c298a2668f0889d07c255da15caec`

Both returned hashes were recomputed directly from
`Returned/returned.fcpxmld/Info.fcpxml` before admission.

## What the verifier established

The same ten checks passed for both packages:

| Check | Movie parent | Still parent | Bounded observation |
| --- | --- | --- | --- |
| source package media hash | pass | pass | The immutable source copy still matched its pinned package digest. |
| rendered package media hash | pass | pass | The connected movie still matched its pinned package digest. |
| source FCPXML hash | pass | pass | The generated input still matched the exact document the evidence names. |
| returned DTD validity | pass | pass | The returned document validates against `FCPXMLv1_14.dtd`. |
| returned FCPXML version | pass | pass | Root version is exactly `1.14`. |
| exact project | pass | pass | Exactly one probe project with the expected name returned. |
| sequence geometry | pass | pass | Four-second `FFVideoFormat1080p30`, 1920x1080 progressive sequence; the expected single parent remained on the spine. |
| unchanged spine | pass | pass | Parent resource/timing stayed intact; no parent visual or audio mutation appeared. The movie parent retained its source audio metadata and dialogue role. |
| connected rendered movie | pass | pass | Exactly one enabled `<video>` child returned at `lane="1"`, `offset="0s"`, inherited/zero start, `duration="4s"`, with no child intrinsics. |
| video-only resource | pass | pass | Connected asset retained video, omitted audio declarations, and retained four-second resource timing. |

The package's closed-render evidence additionally pins the connected resource to
one video stream and zero audio streams: Apple ProRes 422 HQ reported as
`prores` / `HQ` / `apch` / `yuv422p10le`, 1920x1080, 30/1 fps, 120 decoded
frames, and 4/1 seconds. The returned `<video>` had no `adjust-blend` or other
child, so the admitted form is the emitted **default-opaque** construction only.

## Exact admitted surface

This admission covers only all of the following together:

- Final Cut Pro 12.3 (450152) and FCPXML 1.14;
- a 1920x1080 progressive 30 fps, four-second sequence;
- one four-second, video-only ProRes 422 HQ rendered movie;
- one enabled connected `<video>` at lane 1, offset 0, inherited/zero start,
  covering the entire four-second parent;
- no connected-child transform, filter, opacity adjustment, blend adjustment,
  or other intrinsic;
- either the tested still `<video>` parent or tested movie `<asset-clip>` parent;
- an unchanged source spine; for the movie parent, unchanged source audio
  declarations and dialogue role.

## Not admitted

- No retiming claim: neither the connected movie nor either parent was moved,
  trimmed, slipped, stretched, rate-conformed, or otherwise retimed.
- No blend claim beyond the default-opaque, child-free form. Opacity adjustment,
  blend modes, compositing order changes, and mixtures with other intrinsics are
  unobserved.
- No editability claim: nothing in either imported project was edited before
  export.
- No generalization to other codecs, ProRes profiles, pixel formats,
  audio-bearing rendered media, resolutions, frame rates, durations, lanes,
  offsets, starts, multiple connected layers, or parent element kinds.
- No relink, replacement, media-copy, or library-ingest claim. The verifier
  establishes the returned spine structure and package integrity, not future
  media-management behaviour.
- No visual-quality or creative-parameter-mapping claim. This pass establishes
  Final Cut import-and-return semantics for the exact construction only.

## Admission record

`service/FinalCutSemanticProfile.swift` records the movie-parent returned digest
as the primary artifact and carries the still-parent returned digest beside the
limitations. The evidence document is this worksheet, so both required parent
contexts and their exclusions travel with the admitted contract.
