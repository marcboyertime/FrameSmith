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

**Not yet run.**
