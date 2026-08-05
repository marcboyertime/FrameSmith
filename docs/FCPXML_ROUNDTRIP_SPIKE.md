# FCPXML 1.13 Dissolve Admission Probe

`fcpcommandconsole-roundtrip-spike` creates one self-contained, non-overwriting
package from the disposable fixtures. It is intentionally a narrow interchange
gate: it does not launch, automate, modify, or otherwise interact with Final
Cut Pro or any Final Cut library.

Run it with the disposable fixtures and a new operation identifier:

```sh
swift run fcpcommandconsole-roundtrip-spike --fixture-root /Users/marcboyer/Movies/FCPCommandConsole/fixtures --export-root /Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes --operation-id 11111111-2222-3333-4444-555555555555
```

Revision 2 contains exactly two copied movie fixtures, a 1.13 DTD-validated
FCPXML source, typed plan/provenance/manifest/evidence JSON, an empty
`Returned/` directory, and an in-package README. Every `media-rep` URL points to
the package copy rather than a source fixture. It deliberately contains no
still, transform, opacity, color, filter, parameter, keyframe, or effect UID.

The generator accepts only actual regular fixture/DTD/media files: symlinks,
directories, FIFOs, sockets, and devices are rejected. Export roots must be a
strict descendant of `~/Movies/FCPCommandConsole/exports/` or a canonical system
temporary root (`NSTemporaryDirectory()` or `/tmp`); custom CLI paths remain
supported only inside those bounds. It rejects symlink export roots, lexical path
traversal, broad output roots, Final Cut application/library locations, and
existing operation directories. DTD validation uses only local `/usr/bin/xmllint`
with `--nonet` and a ten-second timeout before atomic publication. The timeout
path is intentionally bounded by inspection rather than a deliberately hostile
slow DTD test, because the production validator accepts only the supplied local
DTD and never dereferences network resources.

Revision 1 (`A78B1B9D-60D7-4CD8-960B-FA9104C301E7`) failed during Final Cut Pro
12.3 build 450152 import before native semantics were observed. Revision 2
records incident `42DFFCF1-9E45-41DA-992F-ADB212422B07` as predecessor failure
metadata and does not reuse, alter, or retry its source package.

Import revision 2 only into the disposable **FCPCommandConsole Test** library.
It creates one event/project named **FCPCommandConsole Dissolve Admission
Probe**, with two browser clips and a bare one-second transition. Verify that
import completes without an error or crash, inspect whether the transition
appears, then export the event/project into `Returned/`. If Final Cut errors or
crashes, stop and report immediately. Do not apply color or inspect transforms
in this revision.

DTD validation proves only source syntax. Asset admission, transition semantics,
transition timing/handles, and returned-FCPXML round trip remain `unknown` until
manual import/export evidence exists.

## Outcome of the revision 2 pass (2026-08-03)

Executed once. **Asset admission passed; the bare transition hypothesis is
disproven.** Final Cut imported the reduced package without a crash — the v1
`addAssetClip:` failure did not recur — and returned the transition as:

```xml
<effect id="r2" uid=""/>
...
<transition offset="0s" duration="1s">
    <filter-video ref="r2" enabled="0"/>
</transition>
```

Pinned to the timeline head rather than the 8s cut, backed by a synthesized
effect with an empty UID, and imported disabled. The clips butt-cut at 8s with
no overlap or handles.

The cause is visible in the DTD: `<!ATTLIST transition offset %time; #IMPLIED>`
and `<!ELEMENT transition (filter-video?, …)>`. Both the offset and the effect
reference are optional *for validation* and required *for semantics*, so a
deliberately bare transition validates and then imports as an inert
placeholder. The revision 2 design note above — that the package "deliberately
contains no … effect UID" — is exactly what the probe set out to test, and the
answer is that the omission is fatal.

`evidence.json` inside the package still reads `unknown` for these rows and is
left untouched: the package is the immutable artifact under test. Recorded
evidence lives in `docs/ROUNDTRIP_MANUAL_PASS.md` and
`docs/PHASE1_ACCEPTANCE.md`.

## Revision 3

Generated 2026-08-03 as operation `6B8F8B1C-8171-4770-86C0-E5A859C3B32A`.
Everything Final Cut admitted in revision 2 is unchanged — assets, `asset-clip`
construction, name-only format reference, browser clips. Only the transition
differs:

```xml
<effect id="r4" name="Cross Dissolve" uid="FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265"/>
...
<asset-clip name="clip-a.mov" ref="r2" offset="0s" start="0s" duration="21000/3000s" …/>
<transition name="Cross Dissolve" offset="19500/3000s" duration="3000/3000s">
  <filter-video ref="r4" name="Cross Dissolve">…</filter-video>
</transition>
<asset-clip name="clip-b.mov" ref="r3" offset="19500/3000s" start="3000/3000s" duration="21000/3000s" …/>
```

The UID is derived rather than guessed: `PAECrossDissolve` in
`InternalFiltersXPC.pluginkit/…/Filters.bundle/Contents/Info.plist` declares
protocol `FxTransition` with uuid `4731E73A-8DAC-4113-9A30-AE85B1761265`, and a
real-world transition FCPXML references that uuid as `FxPlug:<uuid>`.

The fixtures are exactly 8 s, so handles had to be made rather than found: both
clips are trimmed to 7 s, leaving clip-a a 1 s tail handle and clip-b a 1 s head
handle. All times are emitted as integers in the 3000-unit timescale so nothing
is produced by floating-point division; `RoundTripSpikeTimeline` holds the
arithmetic and is unit-tested for frame alignment and handle sufficiency.

Open assumption: the centred-offset convention comes from a real-world
transition FCPXML, not from an observed export of this project's own package.
If revision 3 fails on placement rather than on the effect, suspect that first.

## Outcome of the revision 3 pass (2026-08-04)

Executed once. **The Cross Dissolve is admitted; the spine geometry is not.**
The assumption flagged immediately above was the cause.

Final Cut returned the transition intact — our exact UID, no `enabled="0"`,
all four params verbatim — and added a companion it was never given:

```xml
<effect id="r4" name="Cross Dissolve" uid="FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265"/>
<effect id="r5" name="Audio Crossfade" uid="FFAudioTransition"/>
...
<transition name="Cross Dissolve" offset="6s" duration="1s">
  <filter-video ref="r4" name="Cross Dissolve">…</filter-video>
  <filter-audio ref="r5" name="Audio Crossfade"/>
</transition>
```

Final Cut synthesizes an audio crossfade only for a transition it actually
instantiated across two clips with audio. Compare revision 2's synthesized
`<effect uid=""/>` with `enabled="0"`. The effect question is settled: a
`<transition>` needs a real `<effect>` resource and a `<filter-video>`
reference, and with them it is admitted natively.

The layout was re-flowed:

```
sent      clip-a  0 → 7      transition 6.5 → 7.5   clip-b  6.5 → 13.5
returned  clip-a  0 → 6.5    transition 6   → 7     clip-b  6.5 → 13.5
                                                    clip-a  13.5 → 14  (start=6.5s)
```

A `<spine>` is strictly sequential and its children cannot overlap. Revision 3
gave `clip-b` the transition's offset, so it began at 6.5 s while `clip-a` still
ran to 7 s. Final Cut truncated `clip-a` at `clip-b`'s offset and re-appended
the orphaned 0.5 s after `clip-b`.

The transition's own offset was right relative to the resulting joint
(`6 = 6.5 − 0.5`). The corrected rule is therefore:

- transition `offset` = `cut − T/2` — **confirmed**
- incoming clip `offset` = `cut` — the clips butt-join; the transition
  straddles the joint and draws its overlap from their handles

`reference/…/upstream_otio_fcpxml/fcpx_transitions.fcpxml` encodes the
overlapping form (`Clip_A 0→10`, `transition 9.5→10.5`, `Clip_B 9.5→19.5`).
It is OTIO writer output rather than a Final Cut export, and Final Cut does not
accept it as written. Treat it as untrusted for spine geometry.

As with revision 2, the spent package's `evidence.json` is left reading
`unknown`; recorded evidence lives in `docs/ROUNDTRIP_MANUAL_PASS.md` and
`docs/PHASE1_ACCEPTANCE.md`.

## Revision 4

Generated 2026-08-04 as operation `27EA1706-E765-4AC8-9487-54192E5F8DF3`. A
single change from revision 3, keeping every construction Final Cut has
admitted — the assets, the `asset-clip` form, the name-only format reference,
the browser clips, and revision 3's `<effect>` resource, `filter-video`
reference, params, and centred transition offset:

```diff
- <asset-clip name="clip-b.mov" … offset="19500/3000s" start="3000/3000s" duration="21000/3000s"/>
+ <asset-clip name="clip-b.mov" … offset="21000/3000s" start="3000/3000s" duration="21000/3000s"/>
```

A `diff` of the two generated FCPXMLs with operation IDs normalized is that one
line and nothing else, so a revision 4 failure has exactly one possible cause.

The spine now butt-joins: `clip-a` 0→7 s, `clip-b` 7→14 s, with the transition
alone straddling the joint at 6.5→7.5 s and drawing its overlap from the
handles — `clip-a` holds 7–8 s of its source in reserve and `clip-b` holds
0–1 s. `RoundTripSpikeTimeline.incomingOffsetUnits` is now `cutUnits`, and a
unit test asserts the outgoing clip ends exactly where the incoming clip begins
while the transition still straddles that point.

## Outcome of the revision 4 pass (2026-08-04) — accepted

Executed once. **All four semantic rows pass.** The returned spine is what was
sent:

```
sent      clip-a  0 → 7      transition 6.5 → 7.5    clip-b  7 → 14
returned  clip-a  0 → 7      transition 6.5 → 7.5    clip-b  7 → 14
```

Exactly two spine `asset-clip`s, transition at `offset="19500/3000s"` with our
exact UID and no `enabled="0"`, all four params verbatim, a 14 s sequence, and
the `FFAudioTransition` companion again. No markers, no placeholders, no
orphaned elements. Every remaining difference is a lossless normalization:
`21000/3000s` → `7s`, inherited defaults dropped, `tcFormat="NDF"` added,
resource ids renumbered, document version 1.13 → 1.14.

### The construction rules, as established by four revisions

Each revision changed one thing, so each failure had exactly one cause.

| | Construct | Outcome |
| --- | --- | --- |
| 1 | `asset-clip` import | crash during `addAssetClip:` |
| 2 | bare `<transition>`, no effect, no offset | imported disabled at `offset="0s"` |
| 3 | full effect + centred offset + overlapping clips | effect admitted, spine re-flowed |
| 4 | full effect + centred offset + butt-joined clips | **admitted intact** |

1. A `<transition>` needs a real `<effect>` resource and a `<filter-video>`
   referencing it. Omitting either is DTD-valid and semantically inert.
2. The transition's `offset` is `cut − duration/2`.
3. The adjacent clips butt-join at the cut. They must not overlap — a `<spine>`
   is strictly sequential.
4. Both clips need unused source beyond the joint for the dissolve to consume.

DTD validity proves none of this. Rules 1 and 3 both produce perfectly valid
documents that Final Cut then silently rewrites.

This is the project's first Final Cut semantic acceptance. It does not admit
transform, opacity, color, or connected-overlay semantics, and it does not by
itself move a capability gate — see `docs/PHASE1_ACCEPTANCE.md` for why the
contract taxonomy has to be corrected first.
