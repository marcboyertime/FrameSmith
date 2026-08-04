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
