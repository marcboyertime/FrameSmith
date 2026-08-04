# Manual round-trip pass — worksheet

This is the one remaining Phase 1 gate. It cannot be automated: AGENTS.md
forbids AppleScript, Accessibility, and UI automation, so a person drives
Final Cut and records what happened here.

Read `docs/FCPXML_ROUNDTRIP_SPIKE.md` first for what the package contains and
why it is shaped the way it is. This file is the execution sheet.

Package under test (immutable — do not regenerate, edit, or retry it):

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

The input is therefore byte-identical to what was generated and DTD-validated
on 2026-08-03. Re-run the two hash checks if any significant time passes before
the pass is executed.

## Which Final Cut to launch

**Never the stock `/Applications/Final Cut Pro.app`, and never by
double-clicking anything.** The pass runs the reviewed copy at
`~/Applications/SpliceKit/FCPCommandConsole/Final Cut Pro - FCPCommandConsole.app`
through `Scripts/launch-isolated-fcpcommandconsole`, which is the only launch
path that verifies the copy's identity, forces an isolated `HOME`, and applies
`config/fcpcommandconsole-isolation.sb`. That profile denies every `.fcpbundle`
except the disposable library, so a production library cannot be opened even by
accident.

## Steps

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
4. File ▸ Import ▸ XML…, press `⇧⌘G`, paste the absolute path of
   `FCPCommandConsole-RoundTrip-Spike.fcpxml` from the package, and import.
   **Stop and record on any error, alert, beachball, or crash.**
5. Confirm the event **FCPCommandConsole Dissolve Admission Probe** was created
   with two browser clips and a project of the same name.
6. Confirm both clips show real media, not missing-file/red placeholders.
7. Open the project and inspect the spine: two clips with a one-second
   transition between them. Record whether the transition exists at all, and
   the exact name Final Cut gave it.
8. Select the project in the browser, File ▸ Export XML…, press `⇧⌘G`, and
   save into the package's `Returned/` directory. `Returned/` is the only part
   of the package that may be written to.
9. Quit Final Cut. The launcher exits and writes its after-snapshots.
10. Compare the returned FCPXML against the source: asset ids, durations, the
    transition element and its duration, and any normalization Final Cut
    applied.

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

## On crash or alert

1. Note the exact step and the on-screen text verbatim.
2. Capture the new crash report from
   `~/Library/Logs/DiagnosticReports/` and record its incident id.
3. Stop touching the package. Record before any retry or regeneration.

The known predecessor failure, for comparison: revision 1
(`A78B1B9D-60D7-4CD8-960B-FA9104C301E7`) crashed inside
`FFXMLImporter AssetClipImport addAssetClip:toObject:parentFormatID:`,
incident `42DFFCF1-9E45-41DA-992F-ADB212422B07`.

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

Build it as a new operation ID and run it as a separate pass. Do not modify,
regenerate, or retry `CA7D0733-A435-498E-BD82-149CFF863FC3`.
