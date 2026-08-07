# Living Still v2 — layered parallax

Status: **design, not implemented.** v1 stays as-is and keeps working.

## Why there is a v2 at all

v1 does a push-in, a slight pan, a fade, and a saturation nudge. That is a Ken
Burns move with a colour tweak. It is not what "living still" means to anyone
who has seen the effect done well, and the repository has known that from the
start:

- the registry's own aliases include `depthflow parallax`, `parallax`, and
  `2.5d motion`;
- `LivingStillMotionMethod` has exactly one case, `nativePushInPan`;
- `LivingStillDepthFlowStatus` has exactly one case, `deferredUnavailable`.

So v1 is the **native fallback** of an effect whose real form was deferred.
v2 is the effect.

## What the technique actually is

From practitioner sources (see References), the effect is consistent across
tools and has been for a decade:

1. **Separate the image into depth layers.** Two is the working minimum —
   foreground subject and background. Three or more for complex scenes.
2. **Reconstruct what was behind the foreground.** Inpaint or clone the hole.
   Pat David's note is the useful one: the fill *"doesn't have to be 100%
   perfect… It only needs to look good just behind the edges of your foreground
   subjects."*
3. **Move the layers at different rates.** Background slower than foreground —
   roughly 20–30% slower is the commonly cited starting point. The difference in
   rate *is* the effect; everything else is staging.
4. **Keep it subtle.** No source gives numbers here, which is itself
   informative: it is judged by eye and iterated.

Note what this is *not*: it is not a filter, and it is not a single warped
image. It is **several images moving independently**.

## The decision: layers, not a warped render

There are two ways to build it, and they differ in the one dimension this
project cares most about.

| | **v2a — native layered** | **v2b — depth warp render** |
| --- | --- | --- |
| How | N cutout layers, each with its own transform keyframes | Per-pixel displacement driven by a depth map (DepthFlow) |
| Output | FCPXML with connected layers | A baked movie file |
| Motion editable in Final Cut | **yes — every layer, every keyframe** | no |
| Quality ceiling | banding at layer boundaries | smooth, continuous |
| Dependencies | Apple Vision (on device) | Python, PyTorch, DepthFlow (**AGPL-3.0**) |

**v2 is v2a.** The product vision is the tiebreaker, not quality:

> FrameSmith converts ordinary creative language into **transparent, adjustable**
> professional editing operations.

v2b produces a prettier result the user cannot touch. If the background drifts
too much, there is nothing to drag — the only recourse is to regenerate and hope.
v2a produces a slightly cruder result in which the user can select the
background layer in Final Cut and change its keyframes directly, which is the
entire point of the tool.

This also matches the roadmap's compositing preference order: native FCPXML
first, baked render last.

v2b is not rejected forever. It belongs in the Final Phase as an optional
higher-fidelity path, behind the rule that generative or baked processing is
never used where an editable conventional operation will do.

## Pipeline

```
still
  │
  ├─► Vision: VNGenerateForegroundInstanceMaskRequest      (on device, macOS 14+)
  │      └─► subject mask
  │
  ├─► foreground layer   = source × mask            → PNG with alpha
  ├─► background layer   = source, hole filled      → PNG
  │
  └─► FCPXML
         spine:     background   scale 1.06, pans  X units
         lane 1:    foreground   scale 1.10, pans ~1.4× X units
         + existing v1 channels: fade, colour
```

Every layer is a `<video>` with its own `<adjust-transform>`. The **differential
rate** between the spine and lane 1 is the parallax.

### Why Apple Vision rather than a depth model

`VNGenerateForegroundInstanceMaskRequest` is available on this machine
(confirmed macOS 26.3, revision 1). It is on-device, needs no Python, no model
download, and carries no licence obligations — unlike `DepthFlow` (AGPL-3.0) or
SAM2 weights.

It returns a **subject mask**, not a depth map. That is a real limitation: it
gives foreground-versus-background, not a continuous depth field, so it supports
two layers well and three only by heuristic. For the effect described — *"make
objects float around subtly, add some depth"* — two well-separated layers with
correct differential motion delivers most of the perceived result.

A true depth model would allow N bands and is the natural upgrade. It should be
evaluated in Phase D alongside the other segmentation options, not bolted on
here.

### The hole behind the foreground

Three options, cheapest first:

1. **Do nothing.** With small movements the foreground largely covers its own
   hole. Visible only at large offsets.
2. **Edge-extend / blur-fill.** Dilate the background under the mask edge.
   Cheap, and matches "only needs to look good just behind the edges".
3. **Real inpainting.** Best result, most work.

Start at 2. It is a few Core Image operations and avoids the obvious tearing
that 1 produces on anything but the gentlest move.

## What this changes about the claims

v2 is **not** a drop-in for v1, and the differences are exactly the kind this
project tracks.

### Pixel classification changes

v1 is `noBakedPixels` / `sourceMediaPreserved` — the still goes into the project
untouched. v2 **generates new image files** (the cutouts). That is a different
representation and must be recorded as one, not quietly folded in. The source
media is still never modified, but the project no longer references it directly.

### It needs new Final Cut evidence

`connectedOverlayLayers` is admitted, but its record says:

> Only lane 1 was exercised. Lanes below the spine, and **more than one
> connected layer at once**, are unobserved.

Two layers means spine + lane 1, which *is* covered. Three or more means lane 2
and up, which is **not**. So:

- a two-layer v2 can be built on admitted contracts;
- a three-layer v2 needs a multi-lane capture and admission pass first.

Build two layers. Do not skip to three because it seems like the same thing.

### Alpha has never been tested

Every admitted construction so far uses opaque media. A PNG with an alpha
channel imported as a connected layer is unobserved — Final Cut may or may not
honour it without an explicit blend or alpha-handling attribute.

**This needs a capture before an emitter.** It is exactly the shape of thing
that imports cleanly and looks wrong.

## Build order

1. **Capture: alpha in a connected layer.** Import a PNG with transparency as a
   connected clip by hand and read what Final Cut writes. Cheapest unknown, and
   everything else depends on it.
2. **Subject mask extraction.** Vision request → mask → foreground PNG with
   alpha, background PNG with edge-extended fill. Verify by eye on real photos,
   including ones with no clear subject (the request returns nothing — that is a
   refusal path, not a crash).
3. **Two-layer emitter.** Spine background + lane 1 foreground, differential
   transforms, reusing `NativeFCPXMLConnectedLayer`.
4. **Admission pass.** Generated two-layer parallax imported by hand, returned
   and compared.
5. **Editability pass.** Move a background keyframe in Final Cut, confirm it
   takes. This is the claim the whole design rests on — if the layers are not
   independently editable, v2a's advantage over v2b evaporates.
6. **Preview.** The channel sampler already handles one layer; extend to
   composite N.

## What v2 must not become

- **A filter.** If it stops being separable layers, it has become v2b with extra
  steps.
- **Automatic depth guessing presented as certain.** When Vision finds no
  subject, say so and offer v1 — do not invent a foreground.
- **Three layers on two layers' evidence.** See above.

## References

- [Pat David — 2.5D Parallax Animated Photo Tutorial](https://patdavid.net/2014/02/25d-parallax-animated-photo-tutorial/)
  — layer separation, inpainting the clean plate, and the "good enough just
  behind the edges" standard.
- [Waxy — Turning Photos into 2.5D Parallax Animations with Machine Learning](https://waxy.org/2019/11/turning-photos-into-2-5d-parallax-animations-with-machine-learning/)
  — the depth-map lineage of the effect.
- [Pond5 — Create a 2.5D Parallax Effect in Photoshop](https://blog.pond5.com/16853-create-2-5d-parallax-effect-images-photoshop-cc/)
  — the standard foreground/background split.
- [Dream Jacob — 2.5D Parallax in DaVinci Resolve](https://dreamjacob.com/how-to-create-stunning-2-5d-parallax-animations-in-davinci-resolve/)
  — the NLE-native version; notable for giving no numbers, only "subtle".
