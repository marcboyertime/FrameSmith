# Manual round-trip pass — worksheet

This is the one remaining Phase 1 gate. It cannot be automated: AGENTS.md
forbids AppleScript, Accessibility, and UI automation, so a person drives
Final Cut and records what happened here.

Read `docs/FCPXML_ROUNDTRIP_SPIKE.md` first for what the package contains and
why it is shaped the way it is. This file is the execution sheet.

## Revision 4 — pass executed 2026-08-04, **all rows pass**

`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/27EA1706-E765-4AC8-9487-54192E5F8DF3`

Spent evidence; do not regenerate, edit, or retry. Results are in
*Results — pass executed 2026-08-04 21:42–21:46* below.

Generated 2026-08-04 after the revision 3 pass. It keeps **everything** Final
Cut has admitted so far — the assets, the `asset-clip` construction, the
name-only format reference, the browser clips, and revision 3's whole effect
construction — and changes exactly one value:

```diff
- <asset-clip name="clip-b.mov" … offset="19500/3000s" start="3000/3000s" duration="21000/3000s"/>
+ <asset-clip name="clip-b.mov" … offset="21000/3000s" start="3000/3000s" duration="21000/3000s"/>
```

A `diff` of the two generated FCPXMLs, with operation IDs normalized, is that
one line and nothing else. The incoming clip now butt-joins the outgoing clip
at the 7 s cut instead of overlapping it by half a transition, which is what a
strictly sequential `<spine>` requires. Only the transition stays centred on
the joint, drawing its overlap from the handles either side.

**Expected if it works:** a 14 s sequence, `clip-a` 0→7 s, `clip-b` 7→14 s,
transition 6.5→7.5 s, exactly two spine `asset-clip`s, and the effect returning
with our UID and no `enabled="0"` as it already did in revision 3.

Preflight, verified at generation: `probeRevision: 4`, both media SHA-256 and
byte counts match `manifest.json`, DTD-valid against the installed FCPXML 1.13
DTD (checked twice — by the generator before publishing and independently
after), and `Returned/` is empty. `swift build` clean, `swift test` 95 tests /
0 failures, core audit passed.

### Library state before this pass

The disposable library now holds three spent items. Step 4 of the procedure
renames the **revision 3 project** to `REV3 spent 2026-08-04` for the same
reason it renamed revision 2's last time: revision 4 imports under the same
event and project name, and a merged, identically-named project is the one way
this pass could silently record the wrong result.

Media dedupe is expected and is not a failure: earlier imports copied these same
bytes into the library, so the returned `src` may point at media already
present. Asset admission stays observable because `uid`/`sig` derive from the
media itself.

---

# Procedure

This section is revision-independent. Only the package path changes between
passes; for revision 4 it is the path at the top of this file.

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
4. **Rename the previous revision's project** in the browser sidebar — for
   revision 4, rename `FCPCommandConsole Dissolve Admission Probe` (the
   revision 3 project, inside the event of the same name) to
   `REV3 spent 2026-08-04`. Click the name, type, Return. Every revision
   imports under the same event and project name and Final Cut merges them, so
   without this rename there is a live risk of inspecting or exporting the
   previous revision and recording its result as this one's.
5. File ▸ Import ▸ XML…, press `⇧⌘G`, paste the absolute path of
   `FCPCommandConsole-RoundTrip-Spike.fcpxml` from the current package, and
   import. **Stop and record on any error, alert, beachball, or crash.**
6. Confirm a **new** project named `FCPCommandConsole Dissolve Admission Probe`
   appeared alongside the renamed one, with two browser clips. If the only
   project with that name is the one you renamed, stop — the rename did not
   take and the pass is contaminated.
7. Confirm both clips show real media, not missing-file/red placeholders.
8. Open the new project and inspect the spine, then click the transition and
   read the Inspector. Record what you see; the expectations for the current
   revision are at the top of this file.
9. Select the project in the browser, File ▸ Export XML…, press `⇧⌘G`, and
   save into the current package's `Returned/` directory. `Returned/` is the
   only part of a package that may ever be written to.
10. Quit Final Cut. The launcher exits and writes its after-snapshots.
11. Compare the returned FCPXML against the source using the table below.

## Reading the result

The returned XML answers it, not the timeline view.

| Returned value | Meaning |
| --- | --- |
| `<filter-video … enabled="1">`, or no `enabled` at all, which defaults to 1 | the effect was accepted |
| `enabled="0"` | rejected — the revision 2 signature |
| effect `uid` non-empty and matching what we sent | our UID was understood |
| effect `uid=""` | Final Cut synthesized a placeholder |
| a `<filter-audio … uid="FFAudioTransition"/>` we never sent | Final Cut genuinely instantiated the transition — it only enriches real ones |
| transition `offset="19500/3000s"` | placement understood |
| transition `offset="0s"` | placement rejected |
| exactly two spine `asset-clip`s, `clip-a` 0→7 s and `clip-b` 7→14 s | geometry accepted — the revision 4 question |
| a third spine `asset-clip`, or `clip-a` shorter than 7 s | the spine was re-flowed — the revision 3 signature |

## On crash or alert

1. Note the exact step and the on-screen text verbatim.
2. Capture the new crash report from
   `~/Library/Logs/DiagnosticReports/` and record its incident id.
3. Stop touching the package. Record before any retry or regeneration.

The known crash, for comparison: revision 1
(`A78B1B9D-60D7-4CD8-960B-FA9104C301E7`) died inside
`FFXMLImporter AssetClipImport addAssetClip:toObject:parentFormatID:`,
incident `42DFFCF1-9E45-41DA-992F-ADB212422B07`.

## Results — pass executed 2026-08-04 21:42–21:46

Final Cut Pro 12.3 / 450152, reviewed copy, launched via
`Scripts/launch-isolated-fcpcommandconsole --launch`
(provenance `isolated-launch-preflight.dOr4WG`). Returned export written
21:46:03 to
`Returned/FCPCommandConsole Dissolve Admission Probe.fcpxmld/Info.fcpxml`.

**All four rows pass. The dissolve round-trips intact.**

| Row | Status | Evidence |
| --- | --- | --- |
| Import completed without error/crash | **pass** | No alert, error, or crash. |
| Asset admission | **pass** | Both assets returned with real `uid`/`sig`, `videoSources="1" audioSources="1"`, 8s durations, Apple ProRes 422 LT + Linear PCM detected. |
| Cross dissolve native semantics | **pass** | `<effect uid="FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265"/>` — our exact UID. No `enabled="0"` anywhere in the file. All four params verbatim. `FFAudioTransition` companion added again. |
| Transition timing and handles | **pass** | Exactly two spine `asset-clip`s. `clip-a` 0→7s at full duration, `clip-b` `offset="7s" start="1s" duration="7s"`, transition `offset="19500/3000s"` — the value we sent, unchanged. Sequence `duration="14s"`. No orphaned third element. |
| Returned FCPXML round trip | **pass** | Every timing value we sent came back with the same numeric value. |

### Sent versus returned

```
sent      clip-a  0 → 7      transition 6.5 → 7.5    clip-b  7 → 14
returned  clip-a  0 → 7      transition 6.5 → 7.5    clip-b  7 → 14
```

The butt-join rule derived from revision 3's returned file is correct. Every
remaining difference is a lossless normalization:

- `21000/3000s` → `7s` and `3000/3000s` → `1s` — same rational values, reduced.
- `start="0s"` dropped from `clip-a` and `format="r1"` dropped from both spine
  clips, both being defaults inherited from the sequence.
- `tcFormat="NDF"` added; resource ids renumbered; document version 1.13 → 1.14;
  the name-only format resolved to full attributes.

No markers, no disabled filters, no empty UIDs, no synthesized placeholder
effects, no extra spine elements. Nothing in the file needs explaining away.

### What the four revisions establish

| | Construct | Outcome |
| --- | --- | --- |
| 1 | `asset-clip` import | crash during `addAssetClip:` |
| 2 | bare `<transition>`, no effect, no offset | imported disabled at `offset="0s"` |
| 3 | full effect + centred offset + overlapping clips | effect admitted, spine re-flowed |
| 4 | full effect + centred offset + butt-joined clips | **admitted intact** |

Each revision changed one thing and each failure had one cause. The rules that
survived:

1. A `<transition>` needs a real `<effect>` resource and a `<filter-video>`
   referencing it. Omitting either is DTD-valid and semantically inert.
2. The transition's `offset` is `cut − duration/2`.
3. The adjacent clips **butt-join at the cut**. They must not overlap; a
   `<spine>` is strictly sequential.
4. Both clips need unused source beyond the joint for the dissolve to consume.

### What this pass admits

**Asset admission and a fully specified Cross Dissolve, at correct timing,
surviving a full import/export round trip.** This is the first Final Cut
semantic acceptance in the project.

It does **not** admit the `bare_dissolve_transition` contract as currently
named — revision 2 disproved the bare form outright. The contract taxonomy
needs correcting to name what the evidence actually supports before any gate
can move. Nothing here admits transform, opacity, color, or connected-overlay
semantics, and nothing advances the other three workflows.

`evidence.json` inside the package still reads `unknown` and is left untouched;
the package is the immutable artifact under test.

---

Everything below is a completed record.

---

# Revision 3 — completed record

Package (spent evidence; do not regenerate, edit, or retry):

`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/6B8F8B1C-8171-4770-86C0-E5A859C3B32A`

**Outcome: the Cross Dissolve was admitted; the spine geometry was rejected.**

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

The pass followed the shared *Procedure* above. At the time it was run the
library held two spent events — `FCPCommandConsole Round-Trip Spike — Manual
Import Only` (revision 1) and `FCPCommandConsole Dissolve Admission Probe`
(revision 2) — and step 4 renamed the revision 2 item to `REV2 spent
2026-08-03`.

## Results — pass executed 2026-08-04 21:21–21:28

Final Cut Pro 12.3 / 450152, reviewed copy, launched via
`Scripts/launch-isolated-fcpcommandconsole --launch`
(provenance `isolated-launch-preflight.JsuyVQ`). Returned export written
21:28:07 to
`Returned/FCPCommandConsole Dissolve Admission Probe.fcpxmld/Info.fcpxml`.

**The Cross Dissolve is admitted. The spine layout is not.**

| Row | Status | Evidence |
| --- | --- | --- |
| Import completed without error/crash | **pass** | No alert, error, or crash. |
| Asset admission | **pass** | Both assets returned with real `uid`/`sig`, `videoSources="1" audioSources="1"`, 8s durations, Apple ProRes 422 LT + Linear PCM detected. |
| Cross dissolve native semantics | **pass** | Returned as `<transition name="Cross Dissolve">` carrying `<filter-video ref="r4" name="Cross Dissolve">` against `<effect id="r4" uid="FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265"/>` — **our exact UID, preserved**. No `enabled="0"`. All four params round-tripped verbatim. |
| Transition timing and handles | **fail** | Final Cut re-flowed the spine: `clip-a` truncated 7s → 6.5s, and its removed 0.5s tail re-appeared as a **third spine element** at `offset="40500/3000s"`. Handles were not consumed as intended. |
| Returned FCPXML round trip | **partial** | The effect round-tripped faithfully; the spine layout did not. |

### The decisive detail

Final Cut **added** a companion it was never given:

```xml
<effect id="r5" name="Audio Crossfade" uid="FFAudioTransition"/>
...
<filter-audio ref="r5" name="Audio Crossfade"/>
```

It only synthesizes an audio crossfade for a transition it actually
instantiated as a native transition across two clips carrying audio. Revision 2
got a synthesized `<effect uid=""/>` and `enabled="0"`; revision 3 got an
enrichment. That is the difference between a placeholder and a real effect.

### Why the layout failed — overlapping spine siblings

Sent versus returned:

```
sent      clip-a  0 → 7          transition 6.5 → 7.5    clip-b  6.5 → 13.5
returned  clip-a  0 → 6.5        transition 6   → 7      clip-b  6.5 → 13.5
                                                         clip-a  13.5 → 14  (start=6.5s)
```

A `<spine>` is a strictly sequential container; its children cannot overlap.
Our `clip-a` ran to 7 s while `clip-b` began at 6.5 s, so Final Cut resolved
the 0.5 s conflict by truncating `clip-a` at `clip-b`'s offset and re-appending
the orphaned remainder after `clip-b`. Every returned number follows from that:
the orphan is exactly 0.5 s long and its `start="19500/3000s"` is exactly the
truncated portion of the source.

The transition's own placement was *correct relative to the cut Final Cut
ended up with*: `offset="6s"` is `6.5 − 0.5`, centred on the 6.5 s butt joint.
So the centring rule is right and the clip layout rule was wrong.

**Correct convention, derived from the returned file:**

| Element | Rule |
| --- | --- |
| transition `offset` | `cut − T/2` — confirmed correct |
| incoming clip `offset` | **`cut`**, not `cut − T/2` — the clips butt-join and the transition straddles the joint |

Revision 3 set the incoming clip's offset equal to the transition's offset.
That is a one-number error: `clip-b` `offset` should be `21000/3000s` (7 s),
not `19500/3000s` (6.5 s). Handles are then drawn from the clips' unused source
either side of the joint — `clip-a` has 7–8 s spare, `clip-b` has 0–1 s spare —
which is exactly what a 1 s dissolve at a 7 s joint consumes.

### The disproven assumption

The centred-incoming-clip convention came from
`reference/…/upstream_otio_fcpxml/fcpx_transitions.fcpxml`, which lays out
`Clip_A 0→10`, `transition 9.5→10.5`, `Clip_B 9.5→19.5` — the same 0.5 s
sibling overlap. That fixture is OTIO **writer output**, not a Final Cut
export, and Final Cut does not accept it as written. It was flagged in advance
as the first thing to suspect on a placement failure, and it was the cause.
Treat that fixture as untrusted for spine geometry.

### Observations that are not claims

- Returned `media-rep src` points at the **revision 3 package's own `Media/`**,
  not at library-internal media as in revision 2. But `ingestDate` reads
  `2026-08-03 23:22:15` and the asset `uid`s match revision 2's, so Final Cut
  deduplicated against the already-ingested asset and re-pathed it. This is
  **not** proof that leave-in-place referencing works on a first import.
- The step 4 guard worked, at project level rather than event level: the
  revision 3 import merged into the existing event, but because the operator
  had renamed the revision 2 **project** to `REV2 spent 2026-08-03`, the two
  projects are unambiguous and the export contains both.
- That second project independently re-confirms the revision 2 findings from a
  fresh export: `<effect id="r6" uid=""/>`, `<filter-video ref="r6"
  enabled="0"/>`, `offset="0s"`, an 8 s + 8 s butt cut, and the `Marker 1`
  deviation still present on `clip-b`.

### What this pass admits

**Asset admission and cross dissolve native semantics.** Natural dissolve as a
workflow is **not** accepted: correct transition timing is part of it and the
timing row failed. No capability gate has been moved — that is a separate,
deliberate decision and the effect-scoped contract names need revisiting first,
since what was proven is a *fully specified* cross dissolve, not the "bare
dissolve" the taxonomy names. Phase 1 remains **0/4 workflows accepted**.

`evidence.json` inside the package still reads `unknown` and is left untouched;
the package is the immutable artifact under test.

## What revision 4 needs

One number. Keep everything revision 3 proved — the `<effect>` resource, the
UID, the `filter-video` reference, the params, the centred transition offset,
the 7 s clip durations and their handles — and change only the incoming clip's
offset so the clips butt-join instead of overlapping:

```
clip-b  offset="19500/3000s"   →   offset="21000/3000s"
```

Expected result: a 14 s sequence, `clip-a` 0→7 s, `clip-b` 7→14 s, transition
6.5→7.5 s straddling the joint, no orphaned third element, and the transition
returning with our UID and no `enabled="0"` as it already does.

Do not change anything else. Revision 3 isolated the effect question and
answered it; revision 4 must isolate the geometry question the same way, so
that a failure has exactly one possible cause.

**Built** as operation `27EA1706-E765-4AC8-9487-54192E5F8DF3`, described at the
top of this file. A `diff` of the two generated FCPXMLs with operation IDs
normalized is exactly the one line above and nothing else. Revision 3 was not
modified, regenerated, or retried.

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
