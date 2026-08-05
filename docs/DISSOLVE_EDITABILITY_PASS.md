# Dissolve editability pass — worksheet

Section 6 item 2 of `docs/HANDOFF.md`: *natural dissolve manual duration/edge
edits*. This is the second of the four workflow validations and the cheapest,
because the artifact it needs is already in the disposable library.

Read `docs/ROUNDTRIP_MANUAL_PASS.md` first. That pass proved Final Cut
**imports** a cross dissolve faithfully. This one asks a different question:
once imported, is the dissolve a real, editable native transition, or an inert
object that merely survives a round trip?

Import fidelity does not answer that. Revision 2's transition also survived a
round trip — as a disabled placeholder.

## What is under test

The revision 4 project already sitting in the disposable library:

- library: `~/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`
- event: `FCPCommandConsole Dissolve Admission Probe`
- project: `FCPCommandConsole Dissolve Admission Probe`
  (uid `47C758D6-D3EB-4CD3-8BCB-9173C63E6FEF`, imported 2026-08-04 21:45)

No new package is generated. The source package
`27EA1706-E765-4AC8-9487-54192E5F8DF3` stays immutable; the only write is a
**second, differently named** export into its `Returned/` directory, which is
the one writable part of any package.

## The edit

Change the transition's duration from **1 second** to **1 second 20 frames**,
and nothing else.

That value is chosen, not arbitrary:

- 50 frames total, so the half-duration each side is a whole 25 frames and the
  centred offset stays exactly frame-aligned. A 1.5 s transition would be 45
  frames, and 22.5 frames per side is not representable — the result would be
  ambiguous rather than wrong.
- 25 frames of handle needed per side against the 30 frames available
  (`clip-a` holds source 7–8 s, `clip-b` holds 0–1 s). Comfortably inside the
  limit, so a refusal means the transition is not editable rather than that we
  ran out of media.

Expected if the dissolve is genuinely editable, in the 3000-unit timescale:

| | Before | After |
| --- | --- | --- |
| transition duration | `1s` (30 frames) | `5000/3000s` or reduced `5/3s` (50 frames) |
| transition offset | `19500/3000s` (6.5 s) | `18500/3000s` or reduced `37/6s` (6.1667 s) |
| cut position | 7 s | 7 s — unchanged |
| spine `asset-clip` count | 2 | 2 |

The cut must not move and no third element may appear. If the clips re-flow
again, the edit was applied to something that is not a native transition.

## Steps

Stop at the **first** failure. Record before any retry.

1. Confirm no Final Cut is running: `pgrep -lf "Final Cut"` prints nothing.
2. Launch the reviewed copy — never the stock app, never by double-clicking:

   ```sh
   Scripts/launch-isolated-fcpcommandconsole --launch
   ```

3. The isolated `HOME` means no library is remembered; this is expected. Click
   **Open Library** and choose
   `~/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`.
4. Open the project **`FCPCommandConsole Dissolve Admission Probe`** — the one
   *not* named `REV3 spent 2026-08-04`.
5. Click the transition between the two clips to select it.
6. Press `⌃D` (Control-D), type `120`, press Return. That sets 1 second 20
   frames.
   - Dragging the transition's edge is the equivalent gesture and is
     acceptable, but the duration field is exact and a drag is not.
   - **If Final Cut refuses the edit, greys out the field, or the transition
     cannot be selected at all, stop.** That is the finding.
7. Look at the timeline. The cut should stay at 7 s, the transition should be
   visibly longer, and there should still be exactly two clips.
8. Select the project in the browser, File ▸ Export XML…, name the file
   **`after-duration-edit`**, and save it into
   `~/Movies/FCPCommandConsole/exports/roundtrip-spikes/27EA1706-E765-4AC8-9487-54192E5F8DF3/Returned`.
   Do not overwrite the existing export — it is the before-state evidence.
9. Quit Final Cut.

## Reading the result

The returned XML decides it, as always.

| Returned value | Meaning |
| --- | --- |
| transition `duration` = 50 frames and `offset` = 185 frames | **editable** — the edit took and the geometry recomputed correctly |
| duration changed but `offset` unchanged at `19500/3000s` | the transition grew from one side only; it is not being centred on edit |
| duration unchanged | the edit did not apply — inspect whether Final Cut silently reverted it |
| effect `uid` still `FxPlug:4731E73A-…` | still our Cross Dissolve after the edit |
| effect `uid` changed or emptied | Final Cut substituted a different effect during the edit |
| a third spine `asset-clip`, or a moved cut | editing re-flowed the spine — the revision 3 failure signature |

## What a pass would and would not admit

A pass admits **manual duration editability of an imported cross dissolve**,
which is one of the four workflow validations in HANDOFF section 6 item 2.

It would still not accept the natural dissolve workflow. That additionally
requires a capability gate to move, and no trustworthy contract store exists to
move one — see HANDOFF section 6 item 3. Observing a semantic and admitting its
contract remain separate acts.

It admits nothing about transform, opacity, color, or connected overlays.

## Results

**Not yet run.**
