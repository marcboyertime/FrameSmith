# Rotation + anchor ground truth capture

For `native.targeted_rotate_zoom`. **Capture, not a probe** — Final Cut writes
the encoding and we read it. Nothing is predicted, because nothing is known.

## Why this is a capture

`transformKeyframes` is admitted for `position` and `scale` **only**. Rotation
was deliberately left unimplemented in `service/NativeFCPXML/NativeFCPXMLTransformChannel.swift`
because its encoding has never been observed.

The living still capture is the precedent for why guessing is unacceptable
there. It produced three findings that would each have shipped a silently wrong
emitter — including `position` being percent of frame height while the
inspector reads pixels, which would have panned 10.8× too far **and imported
cleanly**. A wrong rotation unit fails exactly the same way: valid XML, wrong
picture, no error.

`position` and `scale` also turned out not to share a shape — one nests into
`X`/`Y` sub-params, the other stays a single param with paired values. So
rotation's shape cannot be inferred from either.

## What to build

One project, one clip, two independent things to read.

- library: `~/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`
- media: `clip-a.mov`, already in the library
- project name: `Rotation Ground Truth`

**Rotation, animated:**

- playhead at frame 0 → Rotation `0°`, set a keyframe
- playhead at frame 60 (`00:00:02:00`) → Rotation `45°`

**Anchor, static:**

- set Anchor to `X 200, Y -100` and leave it un-keyframed

Both live in the same `adjust-transform` and read out as separate params, so one
clip captures both without ambiguity. Leave position and scale untouched — a
capture with fewer moving parts is easier to read, and both are already known.

## Steps

1. `pgrep -lf "Final Cut"` prints nothing.
2. `Scripts/launch-isolated-fcpcommandconsole --launch`
3. Open `/Users/marcboyer/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`.
4. New project named **`Rotation Ground Truth`** (File ▸ New ▸ Project). Accept
   the default 1080p30 settings.
5. Drag `clip-a.mov` into the timeline.
6. Select the clip. Inspector ▸ Video ▸ Transform:
   - playhead at `00:00:00:00`, set **Rotation** to `0` and click the keyframe
     diamond to pin it
   - playhead at `00:00:02:00`, set **Rotation** to `45`
   - set **Anchor** to `200` / `-100` (no keyframe)
7. Select the project in the **browser**, File ▸ Export XML…, name it
   **`rotation-ground-truth`**, save into:

   ```
   ~/Movies/FCPCommandConsole/exports/ground-truth
   ```

8. Quit Final Cut.

## What the capture has to answer

Read out of the returned `adjust-transform`:

| Question | Why it decides the emitter |
| --- | --- |
| Is `rotation` one param, or nested into sub-params? | `position` nests, `scale` does not; rotation could go either way |
| Degrees, radians, or normalized? | `45` vs `0.7853981` vs something else — a wrong unit imports cleanly |
| Does it wrap or accumulate past 360°? | Decides whether multi-turn spins are expressible |
| Is `anchor` one param or nested `X`/`Y`? | Same asymmetry question as position vs scale |
| Is `anchor` in pixels, percent of height, or percent of width? | `position` is percent of **height** despite a pixel inspector; anchor may or may not follow |
| Does anchor appear at all when un-keyframed? | Whether a static non-default value is emitted or inherited |
| Does the keyframe carry a `curve`/interpolation attribute? | `position` Y carried `curve="linear"`; rotation may differ |
| Are keyframe times absolute from the `3600s` origin? | For a `.mov` rather than a still, the origin may not be `3600s` at all |

That last row matters more than it looks. Every keyframe finding so far comes
from a **still**, which Final Cut gives `start="3600s"`. A movie clip has real
source timecode, so the origin will almost certainly differ — and the emitter
has to handle both.

## After the capture

1. Record the findings in this file under Results.
2. Extend `NativeFCPXMLTransformChannel.swift` with a rotation channel and, if
   the encoding differs, an anchor channel.
3. Build a probe with `LivingStillProbeBuilder` as the pattern, in its own
   executable so dissolve and living still evidence stay undisturbed.
4. Run a separate admission pass. **The capture admits nothing** — it records
   what Final Cut writes, not what it accepts on the way in.

## Results

**Captured 2026-08-05**, driven by the agent in the isolated app under the
GUI-automation authorization (HANDOFF §7 constraint 3). Export at
`~/Movies/FCPCommandConsole/exports/ground-truth/rotation-ground-truth.fcpxmld`.

What Final Cut wrote, complete:

```xml
<asset-clip ref="r2" offset="0s" name="clip-a.mov Browser Clip" duration="8s" tcFormat="NDF" audioRole="dialogue">
    <adjust-transform anchor="18.5185 -9.25926">
        <param name="rotation">
            <keyframeAnimation>
                <keyframe time="0s" value="0"/>
                <keyframe time="2s" value="45"/>
            </keyframeAnimation>
        </param>
    </adjust-transform>
</asset-clip>
```

### Finding 1 — `anchor` is an attribute, not a param

This is the one that would have broken an emitter written from intuition.
`anchor` is not a `<param>` at all. It is a **space-separated pair on the
`<adjust-transform>` element itself**.

So `adjust-transform` now has **three** distinct shapes across four properties:

| Property | Shape |
| --- | --- |
| `position` | `<param>` containing nested `X`/`Y` sub-params, each separately animated, each with a `key` attribute |
| `scale` | one `<param>`, paired value (`"1 1"`) |
| `rotation` | one `<param>`, scalar value, **no `key` attribute** |
| `anchor` | **attribute on the parent element**, paired value |

The earlier note that position and scale "do not share a shape" understated it.
There is no general rule to infer here, which is precisely why each property has
to be captured rather than guessed.

### Finding 2 — anchor is percent of frame height, on *both* axes

- `200` px → `18.5185` = 200 / 1080 × 100
- `-100` px → `-9.25926` = −100 / 1080 × 100

Percent of **width** would have given `10.4167` / `-5.2083`. It does not.

This matches `position`: the X axis normalizes against frame *height*, not
width. Two independent properties now confirm that convention, which makes it
much safer to assume for the remaining ones — though still worth a check.

### Finding 3 — rotation is plain degrees

`45` → `value="45"`. Not radians (`0.7853982`), not normalized. The simplest
possibility, and now observed rather than assumed.

### Finding 4 — the `3600s` origin is a property of **stills**, not a rule

Keyframe times here are `0s` and `2s`. Absolute, but from zero.

Every prior timing finding came from the living still, which Final Cut gives
`start="3600s"` and keyframes offset into a 720000 timescale. It was reasonable
to read that as "keyframe times are absolute source time" in general. **It is
not.** A movie clip carries real source time and its asset here is `start="0s"`,
so its keyframes start at `0s`.

An emitter that hardcoded the 3600s origin — which the living still work alone
would have justified — would have placed every movie keyframe an hour early.
This capture is the only reason that is known.

Note also the timescale: `0s` and `2s`, not `/720000s` fractions. The living
still needed fractions because its keyframes landed on frames 108 and 119; these
land on whole seconds and Final Cut writes them plainly.

### Finding 5 — defaults are omitted entirely

`position` and `scale` were untouched and appear **nowhere** in the output — not
as empty params, not as defaults. Only the two properties actually changed were
written.

The emitter should match this. Emitting explicit defaults produces a document
Final Cut would never write, and the living still pass showed that Final Cut
strips inherited defaults on the way back out anyway.

### Finding 6 — no interpolation attribute

Neither keyframe carries `curve`. The living still's `position` Y carried
`curve="linear"`, so the attribute is written only when interpolation differs
from the default, not on every keyframe.

## Follow-up capture — position sign convention and static form

Captured the same session as `position-sign-convention.fcpxmld`, because the
emitter needed the **sign** of `position` Y and no pass had ever observed it.
Normalized image coordinates run y-down; if Final Cut's y runs up, every
vertical pan an emitter produces goes the wrong way — silently, in valid XML.

Setting `Position Y = 200 px` on a clip and reading back:

```xml
<asset-clip ref="r2" offset="0s" name="clip-a.mov Browser Clip" duration="8s" …>
    <adjust-transform position="0 18.5185"/>
</asset-clip>
```

### Finding A — Final Cut's +Y is **up**

The viewer was screenshotted before and after. With `Y = +200` the image moved
**up**, leaving black filling the bottom of the frame.

Normalized image coordinates increase downward, so:

> **XML `position` Y = −(normalized Y offset), expressed as percent of frame
> height.**

The X axis needs no flip; both run positive-right.

This was measured, not judged. The two viewer captures differ unambiguously —
the diagonal test line leaves the top of the frame and a black band appears
along the bottom.

### Finding B — static `position` is an attribute, and a **pair**

`position="0 18.5185"`.

This is the third independent confirmation of the static/animated rule, and by
far the most dramatic, because the two forms of the *same property* barely
resemble each other:

| `position` | Shape |
| --- | --- |
| static | `position="0 18.5185"` — one paired attribute |
| animated | `<param name="position">` containing nested `X` (`key="1"`) and `Y` (`key="2"`) sub-params, each with its own `keyframeAnimation` |

An emitter written from the animated capture alone would emit a param tree for
a value that never moves — a construction Final Cut does not produce. The rule
is now confirmed on `position`, `anchor`, `rotation`, and `adjust-blend/amount`.

### Finding C — Y is percent of frame height too

`200` px → `18.5185` = 200 / 1080 × 100. Same normalization as X and as
`anchor`. Both axes of both properties divide by **height**.

## Open questions this capture does *not* answer

1. **Does `anchor` become a `<param>` when keyframed?** It was captured static,
   which is when it appears as an attribute. An animated anchor may well move
   into the param mechanism. Unobserved — capture before emitting a keyframed
   anchor.
2. **Does rotation wrap or accumulate past 360°?** Only 0→45 was exercised. A
   multi-turn spin is a separate observation.
3. ~~**Rotation direction sign.**~~ **Settled 2026-08-06: positive rotation is
   counterclockwise.**

   Checked without editing anything, by comparing two frames of the already
   imported rotate/zoom project: frame 0 where rotation is `0`, and frame 119
   where it is `30`.

   | | Frame 0 (`0°`) | Frame 119 (`30°`) |
   | --- | --- | --- |
   | colour-bar boundaries | vertical | tops **left** of bottoms |
   | rainbow diagonal | slopes down to the right | slopes **up** to the right |

   A vertical line whose top moves left has rotated counterclockwise, and the
   diagonal's slope flipping sign agrees. Both features move the same way, so
   this is not an artefact of reading one edge.

   This matters for the preview: SwiftUI's `rotationEffect` is
   **clockwise**-positive, so rendering Final Cut's rotation requires negating
   it. `NativeFCPXMLChannelState.rotationDegrees` carries Final Cut's sign and
   the view negates at the point of use.

## After the capture

Steps 2–4 of the plan above still stand: extend
`NativeFCPXMLTransformChannel.swift` with rotation and anchor, build a probe,
and run a separate admission pass. **This capture admits nothing** — it records
what Final Cut writes, not what it accepts on the way in.
