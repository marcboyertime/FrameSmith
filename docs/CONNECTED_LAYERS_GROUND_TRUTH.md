# Connected layers + blend mode ground truth capture

For `look.old_television`. **Capture, not a probe.**

## Why this is the largest remaining unknown

`connectedOverlayLayers` has **no evidence of any kind**. Every probe so far —
four dissolve revisions and the living still — used a single `<spine>` with no
connected clips. It is the only contract of the six that is completely
unobserved, and it is the sole blocker on the fourth workflow.

Blend modes are unobserved too. The living still admission pass exercised
`adjust-blend`'s `amount` (opacity) but never a blend *mode*, so the two are
being captured together.

There is also a structural unknown here that the other captures do not have.
Everything learned so far concerns *attributes on elements inside a spine*.
Connected clips change the **shape of the document** — lanes, connection points,
and offsets relative to the clip they hang off rather than to the timeline. That
is a different class of thing to get wrong, and `service/OverlayAdapter.swift`
and `service/OldTelevisionComposition.swift` cannot be trusted until it is read.

## What to build

- library: `~/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`
- media: `clip-a.mov` and `living-still.png`, both already in the library
- project name: `Connected Layers Ground Truth`

**Spine:** `clip-a.mov`, full length.

**Connected clip:** `living-still.png` attached above it, starting at
**2 seconds**, lasting **3 seconds** — deliberately *not* aligned to the spine
clip's start, so the offset encoding is unambiguous.

On the connected clip:

- Opacity **50%**
- Blend Mode **Overlay**

Two intentional choices. The overlay starts late so a zero offset cannot be
mistaken for a correct one. Overlay is used rather than Screen or Add because it
is unlikely to be a default and will be obvious in the XML.

## Steps

1. `pgrep -lf "Final Cut"` prints nothing.
2. `Scripts/launch-isolated-fcpcommandconsole --launch`
3. Open `/Users/marcboyer/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`.
4. New project named **`Connected Layers Ground Truth`**, default 1080p30.
5. Drag `clip-a.mov` into the timeline as the spine clip.
6. Drag `living-still.png` **above** the spine clip so it attaches as a
   connected clip. Position it to start at `00:00:02:00`.
7. Set the connected clip's duration to 3 seconds (select it, `⌃D`, `300`,
   Return).
8. With the connected clip selected, Inspector ▸ Video ▸ Compositing:
   - **Blend Mode** → `Overlay`
   - **Opacity** → `50%`
9. Select the project in the **browser**, File ▸ Export XML…, name it
   **`connected-layers-ground-truth`**, save into:

   ```
   ~/Movies/FCPCommandConsole/exports/ground-truth
   ```

10. Quit Final Cut.

## What the capture has to answer

| Question | Why it decides the emitter |
| --- | --- |
| Is the connected clip a child of the spine `asset-clip`, or a sibling? | Determines the whole document shape |
| Is there a `lane` attribute, and what numbering does it use? | Lane 1 vs 0 vs -1 decides stacking for multi-layer looks |
| Is `offset` relative to the timeline or to the parent clip? | Starting at 2 s makes this readable; getting it wrong silently misplaces every overlay |
| What element wraps a still used as an overlay — `<video>`, `<asset-clip>`, something else? | The living still used `<video>`; a connected still may differ |
| Does the still still get `start="3600s"`? | Confirms whether the source origin is a property of stills or of the context |
| How is blend mode encoded — an `adjust-blend` `mode` attribute, a param, or a filter? | Wholly unknown |
| Is `Overlay` written as a name, an index, or a UID? | Same class of problem as the Cross Dissolve UID |
| Does opacity ride the same `adjust-blend` as the mode? | The living still had `amount` alone with no mode present |
| Is there a `conform-rate`, `enabled`, or other attribute on connected clips? | Anything unexpected is a construction rule we do not yet have |

## After the capture

1. Record the findings here under Results.
2. Add a connected-layer primitive to `service/NativeFCPXML/`, and a blend-mode
   channel alongside the existing opacity channel.
3. Build an old television probe and run a separate admission pass.
4. **The capture admits nothing.** `connectedOverlayLayers` stays out of
   `FinalCutSemanticProfile` until a generated construction is imported and
   returns intact.

## Results

**Captured 2026-08-05**, driven by the agent in the isolated app. Export at
`~/Movies/FCPCommandConsole/exports/ground-truth/connected-layers-ground-truth.fcpxmld`.

What Final Cut wrote, complete:

```xml
<spine>
    <asset-clip ref="r2" offset="0s" name="clip-a.mov Browser Clip" duration="8s" tcFormat="NDF" audioRole="dialogue">
        <video ref="r3" lane="1" offset="2s" name="living-still" start="10808700/3000s" duration="3s">
            <adjust-blend amount="0.5" mode="14 (Overlay)"/>
        </video>
    </asset-clip>
</spine>
```

### Finding 1 — a connected clip is a **child** of the spine clip

Not a sibling, not a separate spine, not a `<lane>` wrapper. The connected clip
nests **inside** the `asset-clip` it is attached to. That is the document-shape
answer this capture existed to get, and it is the thing
`service/OverlayAdapter.swift` could not have been trusted to guess.

`lane="1"` numbers the first layer above the spine. Lanes below (audio) would
presumably be negative, unobserved.

A still used as a connected clip is a `<video>` element — the same element the
living still probe emits on the spine, so that construction carries over.

### Finding 2 — static values are attributes; animated values are params

This is the general rule, and it now has **two independent confirmations**.

Opacity here is `amount="0.5"` — an **attribute on `<adjust-blend>`**. In the
living still, where opacity was keyframed, it was:

```xml
<adjust-blend>
    <param name="amount"><keyframeAnimation>…</keyframeAnimation></param>
</adjust-blend>
```

The rotation capture showed the same split on `<adjust-transform>`: static
`anchor` was an attribute, animated `rotation` was a `<param>`.

> **Static → attribute on the effect element. Animated → `<param>` child.**

That resolves the open question the rotation capture left: *does `anchor` become
a param when keyframed?* Almost certainly yes, by this rule. It is still worth
one confirming capture before emitting a keyframed anchor, but the rule is no
longer a guess from a single instance.

It also means an emitter cannot pick a shape per property. It must pick per
**property × animated-or-not**.

### Finding 3 — blend mode is an index-and-name string

`mode="14 (Overlay)"`.

This is the same convention already seen in the Color Adjustments payload —
`"0 (SDR)"`, `"11 (Video)"`, `"2 (In & Out)"`. Not a bare index, not a bare
name, not a UID. Whether Final Cut accepts a bare `14` on import is an admission
question this capture does not answer.

### Finding 4 — the `3600s` origin belongs to the still, not the timeline context

`start="10808700/3000s"` = **3602.9 s** = 3600 s + 2.9 s (87 frames).

Two things follow:

1. The 3600 s origin applies to stills **even as connected clips**, so it is a
   property of the still asset, not of being on the spine. Combined with the
   rotation capture — where a movie clip's keyframes started at `0s` — the rule
   is now: **stills get the 3600 s origin, movies do not.**
2. **It cannot be read off the asset.** The asset here declares
   `start="0s" duration="0s"`, yet the clip references 3602.9 s. An emitter that
   derives the origin from the asset's own `start` would emit `0s` and be an
   hour wrong. The origin is a convention Final Cut applies, not data it stores.

The extra 2.9 s is the source in-point, set by where the still was clicked in
the browser before connecting. Incidental to this capture, but it does show the
in-point is expressed in the same 3600 s-based system.

### Finding 5 — untouched properties are omitted

The spine `asset-clip` has no `adjust-blend`, no `adjust-transform`, nothing.
Only what was changed is written. Consistent with the rotation capture, so this
is now confirmed on two different element types.

## Limitation this capture does *not* resolve

**The `offset` reference frame is still ambiguous.** The connected clip has
`offset="2s"` and starts 2 s into the timeline — but its parent `asset-clip` is
itself at `offset="0s"`. Relative-to-parent and relative-to-timeline give the
same answer, so this capture cannot distinguish them.

That is a flaw in the capture design, not in the reading. The worksheet chose a
late start specifically to make the offset readable and then left the parent at
zero, which defeated it.

Resolving it needs a spine with **two** clips and the overlay attached to the
**second** one. If the offset is parent-relative it will restart from 0 at that
clip's start; if timeline-relative it will carry the accumulated time. Until
that is captured, an emitter must not assume either — and for `look.old_television`,
where an overlay may well attach to a non-first clip, getting this wrong
misplaces every overlay silently.

## After the capture

Steps 2–4 above still stand. **This capture admits nothing.**
`connectedOverlayLayers` stays out of `FinalCutSemanticProfile` until a
*generated* connected layer is imported and returns intact.
