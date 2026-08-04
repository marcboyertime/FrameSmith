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

## Results — fill in during the pass

| Row | Status | Evidence |
| --- | --- | --- |
| Import completed without error/crash | unknown | |
| Asset admission (both clips resolve to real media) | unknown | |
| Bare dissolve transition present | unknown | |
| Transition timing / handles preserved | unknown | |
| Returned FCPXML round trip | unknown | |

FCP version/build observed: ______  (expected 12.3 / 450152)
Date/time of pass: ______

## On crash or alert

1. Note the exact step and the on-screen text verbatim.
2. Capture the new crash report from
   `~/Library/Logs/DiagnosticReports/` and record its incident id.
3. Stop touching the package. Record before any retry or regeneration.

The known predecessor failure, for comparison: revision 1
(`A78B1B9D-60D7-4CD8-960B-FA9104C301E7`) crashed inside
`FFXMLImporter AssetClipImport addAssetClip:toObject:parentFormatID:`,
incident `42DFFCF1-9E45-41DA-992F-ADB212422B07`.

## What a success does and does not admit

A clean pass admits **asset admission** and **bare dissolve** only, and only
for the natural-dissolve pathway. It does not admit transform, opacity, color,
or connected-overlay semantics, and it does not advance the other three
workflows — each needs its own package and its own manual pass. Update
`evidence.json`, `docs/PHASE1_ACCEPTANCE.md`, and the `CapabilityGate` contract
only for the rows this pass actually observed.
