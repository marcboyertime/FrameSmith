# Living still — ground-truth capture

Section 6 item 2, fourth bullet: *living still movement/fade/color editability*.

This pass is **not** an admission probe. It runs in the opposite direction:
Final Cut writes the FCPXML and we read it. Nothing is imported.

## Why this order

The dissolve probes could go straight to import because the construction was
already known — four revisions had narrowed it. For the living still, nothing
is known. There is no emitter anywhere in the tree:

```
grep -rn "adjust-transform|adjust-blend|keyframeAnimation" service/ Sources/ Tests/   → no matches
```

`LivingStillComposition` models the effect (4 s, scale 1 → 1.08, panX 0 → 0.02,
enrichment 0 → 0.12, opacity 1 / 1 / 0) but has never been expressed as XML.

Writing that emitter means choosing, with no evidence:

| Unknown | Why guessing is unsafe |
| --- | --- |
| param name for keyframed position/scale | the DTD does not constrain `param/@name`; a wrong name is silently dropped |
| param name for opacity under `adjust-blend` | same |
| units of `adjust-transform/@position` | composition uses a −0.5…0.5 fraction; Final Cut appears to use pixels |
| fade encoding | `<!ELEMENT param (fadeIn?, fadeOut?, keyframeAnimation?, …)>` — a fade may be `fadeOut`, **not** opacity keyframes |
| which color effect | `PAESaturation` is flagged `obsolete=1`; `PAECorrectorEffect` is current |
| keyframe easing spelling | `interp` allows `linear\|ease\|easeIn\|easeOut` — the registry's `ease_in_out` is not one of them |

A wrong guess on any row produces a **confounded** result: the channel comes
back missing and we cannot tell rejection from misspelling. That is precisely
the failure mode the one-variable discipline exists to prevent.

Final Cut already knows every answer. Ask it first.

## What is already derived

From `FCPXMLv1_13.dtd`, so it does not need rediscovering:

- `<video>` is the still's spine element, not `<asset-clip>`. It takes
  `ref`, `lane`, `offset`, `name`, `start`, `duration`, `enabled` — **no
  `format`**.
- Intrinsics are ordered and each may appear at most once:
  `adjust-crop?, adjust-corners?, adjust-conform?, adjust-transform?, adjust-blend?, …`
  So `adjust-transform` precedes `adjust-blend`.
- `adjust-transform` carries `position`/`scale`/`rotation`/`anchor` as
  attributes *and* accepts `param*` children — the keyframing path.
- `<!ELEMENT keyframe EMPTY>` with `time`, `value`, `auxValue`,
  `interp (linear|ease|easeIn|easeOut)`, `curve (linear|smooth)`.
- There is **no `adjust-color`** in 1.13. Color must be a `filter-video`
  referencing an `<effect>` resource — the same shape as the Cross Dissolve.

Color effect candidates, from Final Cut's own
`InternalFiltersXPC.pluginkit/…/Filters.bundle/Contents/Info.plist`:

| class | uuid | obsolete |
| --- | --- | --- |
| `PAECorrectorEffect` | `52A68C6D-B49C-41AA-B3EA-03945D0C8EB4` | 0 |
| `PAESaturation` | `6A06083A-BF89-49B1-9E3D-A2EB1ACBA205` | **1** |

The capture settles which one Final Cut actually writes. Do not pick from this
table by hand.

## Timeline choice

Fade duration is **12 frames (0.4 s)**, not the registry's 0.35 s default.

0.35 s × 30 fps = 10.5 frames, which is not representable. A keyframe there
would be snapped by Final Cut and we could not distinguish snapping from
rejection — the same reasoning that chose 1s20f in
`docs/DISSOLVE_EDITABILITY_PASS.md`. 0.4 s is inside the registry's
`fadeDurationSeconds` range of 0.05…2.0, so nothing is violated.

At 30 fps in the 3000-unit timescale:

| Point | Time | Units | Frame |
| --- | --- | --- | --- |
| start | 0 s | `0s` | 0 |
| fade begins | 3.6 s | `10800/3000s` | 108 |
| end | 4 s | `12000/3000s` | 120 |

## Steps

Exact numbers matter far less than usual here. We are capturing Final Cut's
**encoding**, not its arithmetic — any reasonable construction is authoritative.
If a field will not take a value, use a near one and note what you used.

1. `pgrep -lf "Final Cut"` prints nothing.
2. Launch the reviewed copy:

   ```sh
   Scripts/launch-isolated-fcpcommandconsole --launch
   ```

3. Open `~/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`.
4. **New event**, named `Living Still Ground Truth`. Do not use the dissolve
   event — that library content is spent evidence.
5. Import `~/Movies/FCPCommandConsole/fixtures/living-still.png` into it.
   Leave "copy to library" at whatever it defaults to; the fixture is read-only
   either way and its hash is checked afterwards.
6. New project in that event, 1080p30, named `Living Still Ground Truth`.
7. Put the still on the timeline and set its duration to **4:00** (`⌃D`, `400`).
8. **Movement.** Playhead at frame 0. Inspector ▸ Video ▸ Transform: keyframe
   Scale at `100%` and Position at `0, 0`. Move the playhead to the last frame
   and set Scale `108%`, Position X `38.4`.
   - 38.4 px is 2% of 1920, the composition's `panX = 0.02` read as a fraction
     of frame width. **If the Position field is not in pixels, write down what
     unit it shows** — that single observation resolves the units row above.
9. **Fade.** Inspector ▸ Video ▸ Compositing ▸ Opacity: keyframe `100%` at
   frame 108 and `0%` at frame 120.
   - Use the Opacity parameter, *not* the fade handle on the clip corner. The
     handle likely writes `fadeOut` instead of keyframes, which is a different
     encoding. It is worth capturing too, but not in the same pass.
10. **Color.** Inspector ▸ Color: add a **Color Board** and raise Saturation
    modestly. Keyframe it at frame 0 (neutral) and frame 120 (raised) if that
    is straightforward; if keyframing colour is awkward, a static bump is
    acceptable — the effect's identity and param encoding is what matters.
11. Select the **project** in the browser, File ▸ Export XML…, name it
    `living-still-ground-truth`, and save into:

    ```
    ~/Movies/FCPCommandConsole/exports/ground-truth
    ```

    Create that folder if the dialog does not offer it. It is deliberately
    outside `roundtrip-spikes/` — this is not a probe package and must not be
    filed as one.
12. Quit Final Cut.

## What the return gives us

Every unknown in the first table, answered by Final Cut in its own words:

- the exact nesting for a keyframed intrinsic, and the `param/@name` spellings
- whether opacity really lives under `adjust-blend`
- the true units of `position`
- the real `interp`/`curve` values Final Cut emits for an ease
- the colour effect's `uid`, name, and full param list
- how a still asset is declared: `duration`, `hasVideo`, `videoSources`, and
  which `format` a rate-less image is given

The emitter then gets written against observed output rather than inference,
and the admission probe that follows tests **one** thing — whether our
*generated* form is accepted — instead of testing our guesses.

## What this pass cannot admit

Nothing. No contract moves on the strength of it. Final Cut writing an
encoding says what Final Cut writes; it does not say our generated file will be
admitted, and it says nothing about editability after import. Both need their
own passes.

It is also worth stating plainly: this is Final Cut's construction, not ours.
Copying it is the correct starting point precisely because it is not evidence
about our code.

## Results

**Captured 2026-08-04 22:31.** Final Cut wrote all three channels.

Artifact: `~/Movies/FCPCommandConsole/exports/ground-truth/living-still-ground-truth.fcpxmld`.
Exported as version **1.14**. Fixture hash re-checked after the pass:
`170df534…` unchanged.

Built as specified: 4 s still, Position X 38.4 px and Scale 108 % keyframed
between frame 0 and frame 119, Opacity 100 %→0 % between frames 108 and 119,
Saturation raised to 25 statically. Colour was applied with **Color
Adjustments**, which is what `⌘6` now offers in place of Color Board.

### Every unknown, answered

| Unknown | Answer | |
| --- | --- | --- |
| keyframed `position` | **nested sub-params** `<param name="X" key="1">` / `<param name="Y" key="2">`, each with its own `keyframeAnimation` | wrong guess |
| keyframed `scale` | **single** `<param name="scale">`, paired value `"1 1"` → `"1.08 1.08"` | wrong guess |
| `position` units | **percent of frame height**, not pixels | wrong guess |
| opacity param | `<adjust-blend><param name="amount">`, values `1`→`0` | as guessed |
| colour mechanism | `filter-video` → `<effect>` resource | as the DTD implied |
| colour effect uid | `FxPlug:7E2022A5-202B-4EEB-A311-AC2B585D01B0` | neither candidate |
| easing | no `interp` emitted at all; one `curve="linear"` on the static Y | — |

### The three that would have broken the emitter

**Position and scale do not share a shape.** Position splits into `X`/`Y`
children with independent animations; scale keeps one param with a
space-separated pair. Nothing suggests this asymmetry from outside — the DTD
permits `param*` inside `param` but does not hint that only position uses it.

**Position is normalised to frame height.** The inspector reads `px` and we
entered `38.4`; Final Cut wrote `3.55556`. That is `38.4 / 1080 × 100`. So a
pan expressed as a fraction of *width* converts as

```
xmlX = panXFraction × width / height × 100      // 0.02 → 3.55556 at 1920×1080
```

Emitting the inspector's own number would have panned 10.8× too far — and it
would have imported cleanly, because there is nothing invalid about it. A
silent wrong-magnitude result, not a rejection.

**Keyframe times are absolute source time, not timeline time.** The still is
given `start="3600s"` and every keyframe is offset from that hour, in a
720000 timescale:

| Point | Frame | Emitted time | = |
| --- | --- | --- | --- |
| clip start | 0 | `3600s` | 3600 |
| fade begins | 108 | `2594592000/720000s` | 3603.6 |
| last frame | 119 | `2594856000/720000s` | 3603.96667 |

A keyframe written at `0s` would land an hour before the clip.

### Also worth keeping

- A still is `<video>`, `offset="0s" start="3600s" duration="4s"`, no `format`.
- Its `<asset>` is `start="0s" duration="0s" hasVideo="1" videoSources="1"`
  pointing at a **second** format, `FFVideoFormatRateUndefined`, 1920×1080,
  `colorSpace="1-13-1"`, with no `frameDuration`. The sequence keeps
  `FFVideoFormat1080p30`.
- Final Cut holds a value flat before the first keyframe, so the composition's
  three opacity keyframes (`0 / 3.65 / 4`) need only **two** emitted.
- Y got a single-keyframe animation rather than being omitted.

### The colour blobs are inert

`Color Adjustments` carries three opaque payloads that looked, at first, like a
blocker for synthesising it:

| Payload | Decoded |
| --- | --- |
| `<data key="effectConfig">` | 289-byte NSKeyedArchiver holding exactly `{pluginVersion: 3}` |
| `param key="20"` (unnamed) | 822-char base64 `ozml`, `numberOfKeypoints=0`, `defaultVal == dataValue` |
| `param key="23"` Neutralization Data | 1785-char base64 `ozml`, `numberOfKeypoints=0`, `defaultVal == dataValue` |

Both `ozml` blobs are byte-identical in their default and current values and
carry zero keypoints — they are untouched defaults, not state. The archive is
a version stamp. So the colour channel is very likely synthesisable by copying
these three constants verbatim, or by omitting them.

**Likely, not shown.** Whether Final Cut accepts the filter without them is an
admission question and needs the probe. `Saturation` itself is plain:
`<param name="Saturation" key="16" value="25"/>`, matching the inspector
one-for-one, alongside fifteen sibling params left at `0`.

### Skeleton for the emitter

Blobs elided, structure exact:

```xml
<format id="r1" name="FFVideoFormat1080p30" frameDuration="100/3000s" width="1920" height="1080" colorSpace="1-1-1 (Rec. 709)"/>
<asset id="r2" name="living-still" start="0s" duration="0s" hasVideo="1" format="r3" videoSources="1">
  <media-rep kind="original-media" src="file:///…/living-still.png"/>
</asset>
<format id="r3" name="FFVideoFormatRateUndefined" width="1920" height="1080" colorSpace="1-13-1"/>
<effect id="r4" name="Color Adjustments" uid="FxPlug:7E2022A5-202B-4EEB-A311-AC2B585D01B0"/>
…
<video ref="r2" offset="0s" name="living-still" start="3600s" duration="4s">
  <adjust-transform>
    <param name="position">
      <param name="X" key="1"><keyframeAnimation>
        <keyframe time="3600s" value="0"/>
        <keyframe time="2594856000/720000s" value="3.55556"/>
      </keyframeAnimation></param>
      <param name="Y" key="2"><keyframeAnimation>
        <keyframe time="3600s" value="0" curve="linear"/>
      </keyframeAnimation></param>
    </param>
    <param name="scale"><keyframeAnimation>
      <keyframe time="3600s" value="1 1"/>
      <keyframe time="2594856000/720000s" value="1.08 1.08"/>
    </keyframeAnimation></param>
  </adjust-transform>
  <adjust-blend>
    <param name="amount"><keyframeAnimation>
      <keyframe time="2594592000/720000s" value="1"/>
      <keyframe time="2594856000/720000s" value="0"/>
    </keyframeAnimation></param>
  </adjust-blend>
  <filter-video ref="r4" name="Color Adjustments">
    <param name="Saturation" key="16" value="25"/>
    <!-- 15 sibling params at 0; effectConfig + key 20 + key 23 blobs -->
  </filter-video>
</video>
```

`adjust-transform` precedes `adjust-blend` precedes `filter-video`, matching
`%intrinsic-params-video;` followed by `%video_filter_item;`.

### Standing

Still **nothing admitted**, exactly as this document said before the run. This
is Final Cut's construction, not ours. It tells us what to emit; it does not
show that our generated file will be accepted, and it says nothing about
editability after import. Those remain two separate passes.
