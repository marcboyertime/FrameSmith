# Surprise Me — coverage and verification

Recorded 2026-08-07 against Final Cut Pro **12.3 (450152)**.

## Exact coverage today

| Scenario | Options | Why |
| --- | --- | --- |
| One admitted still, confirmed focal target | **3** | motion (fade), motion+spatial (focal push), look (CRT) |
| One admitted still, no target | 2 | focal push needs a confirmed point and refuses to substitute the centre |
| Two clips for a dissolve | 1 | only one admitted transition exists; the set is not padded |
| Empty semantics profile | 0 | nothing is executable, and the shortfall says so |

The single-still scenario is the shipped end-to-end path and was exercised by
hand in the running app, not only in tests.

## Why the three options are materially different

Diversity is measured on `TreatmentDimension`, and two options must differ on at
least **two** axes. Different names, seeds, or slider nudges do not count.

| Option | Dimensions |
| --- | --- |
| Opacity fade | motion language |
| Focal target push and rotate | motion language + spatial/depth method |
| Old television / CRT | palette/contrast + texture |

The fade and the focal push share one axis and differ on another plus their
effect; the CRT option shares none with either.

## Manual verification performed

In the installed app, 2026-08-07:

1. Admitted `living-still.png` (1920×1080).
2. Set a focal target inside the displayed media; the letterbox correctly
   refused clicks outside it.
3. Pressed **Surprise Me** → three options, each showing its idea, changes,
   what is preserved, editability, cost, and originating card ID.
4. Pressed **Use This** on the focal push → "Applied" badge, that option's
   button disabled, and both export buttons appeared, meaning the selection
   produced a valid, exportable plan.
5. Command text, admitted media, and target were unchanged throughout.

### Two defects this found that tests did not

Both were visible only by looking at the rendered cards:

- **Every option was labelled "Quiet / Cinematic."** The anchor was being
  prefixed unconditionally, so a label meant to distinguish options appeared
  three times and distinguished nothing. It is now included only when the
  selected options actually come from different anchors.
- **The idea line and the first change bullet were identical text**, which made
  the card read like a filled-in template rather than a description.

This is the third time manual review has caught something the suite could not —
the earlier two were silently-rejected target clicks and content clipping below
the fold.

## Final Cut import verification

Both emitters generalized in this milestone were verified by real import, not by
DTD validity:

| Emitter | Package | Returned |
| --- | --- | --- |
| Natural dissolve | `98B764EB` | transition at `offset="7s"` `duration="1s"`, four params byte-identical, UID preserved, clips still butt-joined, 15 frames of handle |
| Old television | `9614E989` | three-keyframe flicker in animated param form with movie-origin times, Color Adjustments UID and payloads preserved |

Final Cut added its own `FFAudioTransition` companion to the dissolve — the same
behaviour the original fixed-timeline probe produced, which is a useful sign the
generalized construction is being treated identically to the admitted one.

## Known limitations

1. **Old television's connected overlay is unexercised by its emitter.** The
   plan role model carries no overlay asset, so only the base treatment
   (flicker + colour) can be generated. Lane, parent-relative offset, and blend
   mode remain admitted from the earlier probe.
2. **Colour is indicative only.** No measured mapping connects a creative
   intensity to the 0–100 Saturation param.
3. **No audio, typography, masking, or tracking.** Those cards are
   `reference_only` and cannot be offered.
4. **Options were not rendered and compared frame-by-frame.** The bakeoff
   procedure in `process.review.representative_bakeoff.v1` describes what a full
   visual pass requires — varied media, key-frame inspection, loudness-matched
   audio — and that has not been run. What is claimed here is construction
   correctness and UI behaviour, not comparative image quality.
5. **Only the Overlay blend mode has ever been observed.**
