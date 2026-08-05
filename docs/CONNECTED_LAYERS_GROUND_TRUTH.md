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

**Not yet run.**
