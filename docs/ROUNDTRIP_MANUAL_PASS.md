# Manual round-trip pass — worksheet

This is the one remaining Phase 1 gate. It cannot be automated: AGENTS.md
forbids AppleScript, Accessibility, and UI automation, so a person drives
Final Cut and records what happened here.

Read `docs/FCPXML_ROUNDTRIP_SPIKE.md` first for what the package contains and
why it is shaped the way it is. This file is the execution sheet.

## Current package under test — revision 3

`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/6B8F8B1C-8171-4770-86C0-E5A859C3B32A`

Generated 2026-08-03 after the revision 2 pass. It keeps everything Final Cut
already admitted in revision 2 — the assets, the `asset-clip` construction, the
name-only format reference, the browser clips — and changes only the four
things revision 2 proved wrong:

| Revision 2 | Revision 3 |
| --- | --- |
| no effect resource → Final Cut synthesized `<effect uid=""/>` | `<effect id="r4" name="Cross Dissolve" uid="FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265"/>` |
| bare `<transition>` → returned `enabled="0"` | `<filter-video ref="r4">` with the standard Look/Amount/Ease params |
| no `offset` → returned pinned to `0s` | `offset="19500/3000s"`, centred on the 7s cut |
| two 8s clips butted at 8s, nothing to dissolve through | clips trimmed to 7s: clip-a keeps a 1s tail handle, clip-b starts 1s into its source |

The UID was derived, not guessed: `PAECrossDissolve` in Final Cut's
`InternalFiltersXPC.pluginkit/…/Filters.bundle/Contents/Info.plist` declares
protocol `FxTransition` with uuid `4731E73A-8DAC-4113-9A30-AE85B1761265`, and a
real-world transition FCPXML references it as `FxPlug:<uuid>`. Two independent
sources, agreeing.

**Open assumption:** the centred-offset convention comes from a real-world
transition FCPXML, not from an observed export of our own package. If revision 3
fails on placement rather than on the effect, that convention is the first thing
to suspect.

## Preflight — re-verified 2026-08-04, immediately before the pass

Read-only. No Final Cut interaction.

| Check | Result |
| --- | --- |
| Working tree at `dbd3d76`, clean | pass |
| `probeRevision` in `manifest.json` and `evidence.json` | `3` |
| `Media/clip-a.mov` SHA-256 + byte count vs `manifest.json` | match (`cd44c0c9…`, 47,002,621 bytes) |
| `Media/clip-b.mov` SHA-256 + byte count vs `manifest.json` | match (`a38a03bf…`, 16,261,915 bytes) |
| `FCPCommandConsole-RoundTrip-Spike.fcpxml` vs installed FCPXML 1.13 DTD | valid (`xmllint --nonet --dtdvalid`) |
| `Returned/` | empty — the pass has not been run |
| `evidence.json` semantic rows | all four `unknown`, including asset admission |
| `pgrep -lf "Final Cut"` | nothing running |
| `Scripts/launch-isolated-fcpcommandconsole --preflight-only` | `preflight=pass` (provenance `isolated-launch-preflight.bVdMUV`) |

Note for anyone re-running the DTD check by hand: `xmllint --dtdvalid` takes a
**URI**, so the DTD's real path inside `Final Cut Pro.app` fails to parse purely
because it contains spaces. Copy the DTD to a space-free path first; this is a
quoting artifact, not a validation failure.

## Known state of the disposable library

The library already holds two spent events from earlier passes:

- `FCPCommandConsole Round-Trip Spike — Manual Import Only` (revision 1)
- `FCPCommandConsole Dissolve Admission Probe` (revision 2)

Revision 3 imports under **the same event name as revision 2**, and Final Cut
merges same-named events on XML import. Step 4 below renames the revision 2
event first so the revision 3 import lands in an unambiguously new event.
Without that rename there is a live risk of inspecting — or exporting — the
revision 2 project and recording its result as revision 3's.

Media dedupe is expected and is not a failure: revision 2's import copied these
same bytes into the library, so revision 3's returned `src` may point at media
already present. Asset admission is still observable, because `uid`/`sig` derive
from the media itself.

## Which Final Cut to launch

**Never the stock `/Applications/Final Cut Pro.app`, and never by
double-clicking anything.** The pass runs the reviewed copy at
`~/Applications/SpliceKit/FCPCommandConsole/Final Cut Pro - FCPCommandConsole.app`
through `Scripts/launch-isolated-fcpcommandconsole`, which is the only launch
path that verifies the copy's identity, forces an isolated `HOME`, and applies
`config/fcpcommandconsole-isolation.sb`. That profile denies every `.fcpbundle`
except the disposable library, so a production library cannot be opened even by
accident.

## Steps — revision 3

Stop at the **first** failure. Do not retry, do not regenerate, do not move to
the next step.

1. Confirm no Final Cut is running: `pgrep -lf "Final Cut"` prints nothing.
   The launcher refuses to start otherwise.
2. Launch, from the repo root, in a terminal you can leave open — the command
   blocks until Final Cut quits:

   ```sh
   Scripts/launch-isolated-fcpcommandconsole --launch
   ```

   It prints `preflight=pass` and a provenance directory before launching.
   If it prints anything else and exits, stop and record that output; the
   pass has not started.
3. Confirm the open library is **`FCPCommandConsole Test`** and nothing else.
   If no library opens, File ▸ Open Library ▸ Other… and choose
   `~/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle`. An error when
   any *other* library is offered is the sandbox working correctly, not a
   probe failure — record it and carry on with the disposable library.
4. In the browser sidebar, rename the existing event
   **`FCPCommandConsole Dissolve Admission Probe`** to
   **`REV2 spent 2026-08-03`** (click the name, type, Return). This is the
   revision 2 event and it must not absorb the revision 3 import.
5. File ▸ Import ▸ XML…, press `⇧⌘G`, paste the absolute path of
   `FCPCommandConsole-RoundTrip-Spike.fcpxml` from the revision 3 package, and
   import. **Stop and record on any error, alert, beachball, or crash.**
6. Confirm a **new** event named `FCPCommandConsole Dissolve Admission Probe`
   was created, with two browser clips and a project of the same name. If the
   import instead landed in `REV2 spent 2026-08-03`, stop — the rename did not
   take and the pass is contaminated.
7. Confirm both clips show real media, not missing-file/red placeholders.
8. Open the new project and inspect the spine. Expected shape, if revision 3
   works: a timeline about **13.5 s** long, `clip-a` from 0 s to 7 s, the
   transition straddling the cut from **6.5 s to 7.5 s**, and `clip-b` running
   from 6.5 s to 13.5 s. Record: does the transition exist; where is it; what is
   it called; and — click it — does the Inspector show an enabled **Cross
   Dissolve** rather than a blank effect.
9. Select the project in the browser, File ▸ Export XML…, press `⇧⌘G`, and
   save into the revision 3 package's `Returned/` directory. `Returned/` is the
   only part of the package that may be written to.
10. Quit Final Cut. The launcher exits and writes its after-snapshots.
11. Compare the returned FCPXML against the source using the table below.

## Reading a revision 3 result

The returned XML answers it, not the timeline view. Compare against revision 2's
failure signature:

| Returned value | Meaning |
| --- | --- |
| `<filter-video … enabled="1">` (or no `enabled`, which defaults to 1) | the effect was accepted |
| `enabled="0"` | still rejected — as in revision 2 |
| effect `uid` non-empty and matching what we sent | our UID was understood |
| effect `uid=""` | Final Cut again synthesized a placeholder |
| transition `offset` near `19500/3000s` | placement understood |
| transition `offset="0s"` | placement still wrong — suspect the centred-offset convention |
| clip-b `offset` ≈ clip-a end minus half the transition | handles consumed as intended |

## On crash or alert

1. Note the exact step and the on-screen text verbatim.
2. Capture the new crash report from
   `~/Library/Logs/DiagnosticReports/` and record its incident id.
3. Stop touching the package. Record before any retry or regeneration.

The known predecessor failure, for comparison: revision 1
(`A78B1B9D-60D7-4CD8-960B-FA9104C301E7`) crashed inside
`FFXMLImporter AssetClipImport addAssetClip:toObject:parentFormatID:`,
incident `42DFFCF1-9E45-41DA-992F-ADB212422B07`.

## Results — revision 3

**Not yet run.** All four semantic rows remain `unknown`. Nothing about
revision 3's Final Cut behaviour may be claimed until this section records an
executed pass.

---

Everything below describes `CA7D0733…` and is the completed revision 2 record.

---

# Revision 2 — completed record

Package (spent evidence; do not regenerate, edit, or retry):

`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/CA7D0733-A435-498E-BD82-149CFF863FC3`

## Preflight — verified 2026-08-03 (read-only, no Final Cut interaction)

| Check | Result |
| --- | --- |
| `Media/clip-a.mov` SHA-256 + byte count vs `manifest.json` | match (47,002,621 bytes) |
| `Media/clip-b.mov` SHA-256 + byte count vs `manifest.json` | match (16,261,915 bytes) |
| `FCPCommandConsole-RoundTrip-Spike.fcpxml` vs installed FCPXML 1.13 DTD | valid (`xmllint --nonet --dtdvalid`) |
| `Returned/` | empty — the pass has not been run |
| `evidence.json` semantic rows | all four still `unknown` |
| Disposable library `~/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle` | present |
| `media-rep` `src` URLs | point at the package's own `Media/`, not the fixtures |
| `Scripts/launch-isolated-fcpcommandconsole --preflight-only` | `preflight=pass` (copied-app identity, entitlements, sandbox probes, no FCP running, preferences unchanged) |

The input was therefore byte-identical to what was generated and DTD-validated
on 2026-08-03.

The pass followed the same launch path and step sequence documented above for
revision 3, minus the step 4 event rename, which did not yet apply.

## Results — pass executed 2026-08-03 23:19–23:28

Final Cut Pro 12.3 / 450152, reviewed copy, launched via
`Scripts/launch-isolated-fcpcommandconsole --launch`
(provenance `isolated-launch-preflight.M4kLXl`). Returned export:
`Returned/FCPCommandConsole Dissolve Admission Probe.fcpxmld/Info.fcpxml`.

| Row | Status | Evidence |
| --- | --- | --- |
| Import completed without error/crash | **pass** | No alert, error, or crash. Event and project both created. The v1 crash in `addAssetClip:toObject:parentFormatID:` did not recur. |
| Asset admission | **pass** | Both assets returned with real `uid`/`sig`, `videoSources="1" audioSources="1"`, 8s durations, codecs detected as Apple ProRes 422 LT + Linear PCM. |
| Bare dissolve transition present | **fail** | Returned as `<transition offset="0s" duration="1s"><filter-video ref="r2" enabled="0"/></transition>` with a synthesized `<effect id="r2" uid=""/>`. Pinned to the timeline head, not the cut; no real effect; imported disabled. |
| Transition timing / handles preserved | **fail** | `clip-a` `offset="0s"` dur 8s, `clip-b` `offset="8s"`, sequence `duration="16s"`. Exactly 8+8 — butt cut, zero overlap, no handles. |
| Returned FCPXML round trip | **partial** | The export mechanism works: a readable `.fcpxmld` bundle was produced. The content did not round-trip faithfully — the transition was rewritten as above. |

### Normalizations Final Cut applied

- Document version `1.13` → `1.14`.
- `<format id="r1" name="FFVideoFormat1080p30"/>` resolved to full
  `frameDuration="100/3000s" width="1920" height="1080"
  colorSpace="1-1-1 (Rec. 709)"`. **Name-only format references are accepted.**
- Media was **copied into the library**: returned `src` points at
  `FCPCommandConsole Test.fcpbundle/…/Original Media/`, not at the package copy.
  What is proven is import-with-copy; leave-in-place referencing is untested.
- Library scaffolding (smart collections) added by the exporter.

### Deviation

The returned XML contains a marker the source never had:
`<marker start="17/15s" duration="100/3000s" value="Marker 1"/>` on `clip-b`.
The operator does not recall pressing `M` and it cannot be proven either way.
It is recorded as an operator artifact: it is exactly one frame long at 30fps,
frame-aligned at frame 34, and carries Final Cut's default sequential name for
a manually created marker — no XML import path synthesizes markers, and the
analysis features name theirs descriptively. The project `modDate`
(23:24:30) falls between import (23:22:15) and export (23:28).

It does not bear on either finding: asset admission was settled at import
before any marker could exist, and a marker on `clip-b` cannot cause a
transition to be placed at offset 0, disabled, with an empty effect UID.

## What this pass admits

**Asset admission only.** Natural dissolve is **not** accepted: it requires
asset admission *and* bare dissolve, and bare dissolve failed. No capability
gate moves — `SemanticProfile` has no persisted contract store and defaults to
an empty admitted set, so every FCPXML pathway stays closed. Phase 1 remains
**0/4 workflows accepted**.

Nothing here admits transform, opacity, color, or connected-overlay semantics,
and nothing advances the other three workflows.

Do not edit `evidence.json`, `manifest.json`, or anything else inside the
package. It is the immutable artifact under test and `Returned/` is the only
part that may be written. Evidence is recorded here and in
`docs/PHASE1_ACCEPTANCE.md`, which are version-controlled.

## What revision 3 needs

The probe's hypothesis — that a bare `<transition>` element is enough — is
disproven. DTD validity does not imply transition semantics: `offset` and the
`filter-video` child are both `#IMPLIED` in the DTD, and omitting them produced
a disabled placeholder at the wrong time. A revision 3 package needs all four:

1. An `<effect>` resource carrying the real Cross Dissolve UID, not a bare
   `name` attribute.
2. A `<filter-video ref="…">` child on the transition pointing at it, enabled.
3. An explicit `offset` straddling the cut — for a 1s transition at an 8s cut,
   `offset="7.5s"`, since Final Cut centres a transition on the edit point.
4. Handles: both clips need media beyond the cut for the dissolve to run
   through. With `duration="8s"` clips butted at 8s there is nothing to
   dissolve. Either trim the clips shorter than their source media or extend
   the assets.

**Built.** All four are implemented in `service/FCPXMLRoundTripSpike.swift` and
published as operation `6B8F8B1C-8171-4770-86C0-E5A859C3B32A`, described at the
top of this file. `CA7D0733-A435-498E-BD82-149CFF863FC3` was not modified,
regenerated, or retried.
