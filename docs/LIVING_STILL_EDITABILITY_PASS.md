# Living still editability pass — worksheet

Section 6 item 2, fourth bullet, second half. `docs/LIVING_STILL_ADMISSION_PASS.md`
proved Final Cut **imports** the generated construction intact. This asks the
separate question: are the keyframes **natively editable** once imported, or
inert objects that merely survive a round trip?

Revision 2 of the dissolve round-tripped as a disabled placeholder. Import
fidelity has never implied editability in this project, and it does not here.

## What is under test

The already-imported probe, untouched since the admission pass:

- library: `~/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`
- event / project: `FCPCommandConsole Living Still Admission Probe`
  (uid `0C548309-62D2-4740-9C58-1A171B7C294C`)

The still is 4 s — frames 0–119 — starting at source `3600s` in a 720000
timescale. Its keyframes as imported:

| Channel | Frame 0 | Frame 108 | Frame 119 |
| --- | --- | --- | --- |
| `position` X | `0` | — | `3.55556` |
| `position` Y | `0` (linear) | — | — |
| `scale` | `1 1` | — | `1.08 1.08` |
| `adjust-blend` amount | — | `1` | `0` |

Frame 119 is `time="2594856000/720000s"`, frame 108 is `2594592000/720000s`.

## The three edits

Ordered easiest to fiddliest. **Stop at the first failure** — that is the
finding, and a later success would not undo it.

### Edit 1 — scale, frame 119: 108% → 120%

Expected returned value `1.2 1.2`.

Tests whether a transform keyframe accepts a new value in place.

### Edit 2 — position X, frame 119: 38.4 px → 54 px

Expected returned value **`5`**.

This value is chosen, not arbitrary. `position` is percent of frame *height*
even though the inspector reads pixels, and 54 / 1080 × 100 = **exactly 5**. A
round number in the returned XML confirms the unit conversion from the *edit*
direction, which the admission pass could only confirm from the emit direction.

If the returned value is ~`2.8125` (54/1920) the unit is percent of *width* and
the ground-truth finding is wrong about which axis normalizes it. If it is `54`,
the field is literal pixels on import-then-edit but not on emit — a direction
asymmetry worth knowing about.

### Edit 3 — opacity, frame 119: 0% → 25%

Expected returned `adjust-blend` amount value **`0.25`**.

Opacity is a separate contract from transform, so it needs its own observation
even though both live on the same clip.

## Critical technique

**Park the playhead exactly on the keyframe before changing a value.** If the
playhead is anywhere else, Final Cut adds a *new* keyframe instead of editing
the existing one, and the result reads as a failure that was actually a
mis-click.

Use the keyframe navigation arrows in the Inspector (the `‹ ◆ ›` control beside
an animated parameter) — they jump the playhead exactly onto a keyframe. Do not
scrub by hand and do not trust the timecode field for this.

The keyframe **count must not change**. Three keyframes where there were two
means a new one was added, not an edit applied.

## Steps

1. `pgrep -lf "Final Cut"` prints nothing.
2. Launch the reviewed copy:

   ```sh
   Scripts/launch-isolated-fcpcommandconsole --launch
   ```

3. Open `/Users/marcboyer/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`
   (absolute path — `~` resolves inside the sandbox HOME).
4. Open the project `FCPCommandConsole Living Still Admission Probe`.
5. **Play it once first** and record what you see — this also closes the
   outstanding render-confirmation gap from the admission pass. Expect a slow
   push-in, a slight rightward drift, a modestly richer image, and a fade to
   black over the last twelve frames.
6. Select the still. In the Inspector, use the keyframe arrows to jump to the
   **last** `Scale` keyframe and set Scale to **120%**.
7. Jump to the last `Position` X keyframe and set X to **54 px**.
8. Jump to the last `Opacity` keyframe and set Opacity to **25%**.
9. Select the project in the **browser** (not the timeline), File ▸ Export XML…,
   name it **`after-keyframe-edits`**, and save into:

   ```
   ~/Movies/FCPCommandConsole/exports/living-still-probes/3E660E97-DBD8-40EA-88F9-C926CD424FDE/Returned
   ```

   Do not overwrite `returned.fcpxmld` — that is the before-state evidence.
10. Quit Final Cut.

## Reading the result

| Returned state | Meaning |
| --- | --- |
| `scale` = `1.2 1.2`, `position` X = `5`, amount = `0.25`, two keyframes each | **editable** — all three channels take edits in place |
| any value unchanged | that channel did not accept the edit; inspect whether Final Cut reverted it |
| a third keyframe appears | the playhead was not on the keyframe; re-run that edit rather than recording a failure |
| `position` X = `2.8125` | percent of width, not height — the ground truth finding is wrong |
| `position` X = `54` | literal pixels on edit but percent on emit — a direction asymmetry |
| keyframe `time` values shifted | editing re-timed the animation; the `3600s` origin is not stable under edit |
| `effect` uid emptied or `enabled="0"` | the colour effect was torn down by an unrelated edit |

## What a pass would and would not admit

A pass admits **manual keyframe editability of a generated living still** —
transform and opacity, at the values tested.

It would not admit rotation (unobserved, and not present in this probe), blend
modes (never exercised), the `colorEnrichment` → `Saturation` mapping (still
unobserved), or editability of the colour effect's parameters. It moves no
capability gate on its own; `look.old_television` stays blocked on
`connectedOverlayLayers` regardless.

## Results

**Run 2026-08-05. Pass — all three edits took, plus one unpredicted finding.**

Export `Returned/after-keyframe-edits.fcpxmld`, sha256
`1f32d6da03ef531449c42aab2da9d7b0081ccb6e3c0c22e6d3cebf49fa9085c0`.

| Edit | Predicted | Returned | |
| --- | --- | --- | --- |
| `scale` frame 119 | `1.2 1.2` | `1.2 1.2` | pass |
| `position` X frame 119 | `5` | `5` | pass |
| `adjust-blend` amount frame 119 | `0.25` | `0.25` | pass |
| keyframe times | unchanged | unchanged | pass |
| effect uid / `enabled` | untouched | untouched | pass |

**The generated living still is natively editable.** Its keyframes are real
keyframes, not inert data that survived an import.

### The unit conversion is confirmed in both directions

Typing `54` px into the inspector produced exactly `5` in the XML — 54 / 1080 ×
100. The admission pass could only show that our emitted `3.55556` survived a
round trip, which is consistent with Final Cut simply not touching a value it
never interpreted. This shows Final Cut *computing* the same conversion from a
fresh human-entered number.

`position` is percent of frame **height**, on a 1920×1080 frame, in both
directions. It was the finding most likely to be an artefact of the capture, and
it is not.

### Unpredicted: editing one position axis writes a keyframe on both

The document gained one node — 39 → 40. `position` Y, which had a single
keyframe at `3600s`, came back with a second at `2594856000/720000s`, value `0`.

Nothing else moved, and the value is `0`, so there is **no visual change**. But
it is a real structural finding, and it was not predicted:

> Final Cut treats Position as one editable unit in the inspector even though it
> encodes as two independently animated sub-params. Editing either axis at a
> given time writes a keyframe on **both** axes at that time.

Three consequences worth carrying forward:

1. **Round-trip comparisons must expect it.** A strict node-count or
   tree-equality check on a user-edited position will report a false difference.
   The admission pass could compare 40 nodes to 40; this one cannot.
2. **The emitter should probably match it.** Emitting a lone X keyframe produces
   a document Final Cut would never have written itself. It imported fine here,
   so this is a consistency preference rather than a requirement — but the
   asymmetry is now a known place where our output and Final Cut's diverge.
3. **The X/Y split is an encoding detail, not a user-facing one.** For Phase B,
   `position` is one primitive with two components, not two primitives. The
   inspector already treats it that way and so should FrameSmith.

### What this admits

**Manual keyframe editability of a generated living still** — transform
(position, scale) and opacity, at the values tested. Combined with the admission
pass and the render confirmation, `motion.living_still` is now observed
end-to-end for the channels it uses: emitted, imported intact, rendering, and
editable.

It admits nothing about rotation (unobserved, absent from this probe), blend
modes (never exercised), the colour effect's *parameters* (only its construction
was tested; no parameter was edited), or the `colorEnrichment` → `Saturation`
mapping. It moves no capability gate on its own, and `look.old_television`
remains blocked on `connectedOverlayLayers`.
