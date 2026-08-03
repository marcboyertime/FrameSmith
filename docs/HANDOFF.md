# FCPCommandConsole handoff

Written 2026-08-03. Supersedes the earlier Phase 1 handoff, which is preserved in
Git history and described under "History" below.

**Read this section first.** The project has pivoted. The private Final Cut
integration is finished as an experiment and archived. The primary product is now
a standalone macOS application that generates media and FCPXML the user imports
into Final Cut Pro manually.

---

## 1. Exact current state

| Item | Value |
| --- | --- |
| Repository | `/Users/marcboyer/Developer/FCPCommandConsole` |
| Current branch | `standalone-app` |
| HEAD | `9d8b680def711accf80ce94637ad5096b11d32d1` |
| Working tree | clean |
| Branches | `main`, `standalone-app`, `archive/splicekit-private-integration` (all at `9d8b680`) |
| Tag | `archive/splicekit-private-integration` |
| Git remotes | none, by policy |
| Tests | 52 passing (`swift test`) |
| Build | `swift build` succeeds |
| Final Cut processes | none running |

All three branches currently point at the same commit. `standalone-app` is where
new work goes. The archive tag exists so the private integration can be revisited
without complicating the standalone app.

### Runtime paths

| Path | Purpose |
| --- | --- |
| `/Users/marcboyer/Movies/FCPCommandConsole` | runtime root: provenance, fixtures, overlays, renders, logs |
| `/Users/marcboyer/Movies/FCPCommandConsole/fixtures` | `clip-a.mov`, `clip-b.mov`, `living-still.png`, `manifest.json` |
| `/Users/marcboyer/Applications/SpliceKit/FCPCommandConsole/…app` | the copied Final Cut app (Schema 16 installed, experimental only) |
| `/Applications/Final Cut Pro.app` | stock app, never modified, hash unchanged all session |

Fixture SHA-256, verified unchanged after every live run:

```
clip-a.mov       cd44c0c9565c8231ec421541f4a4877f340eae7db5129fb46ffa14f0bf871444
clip-b.mov       a38a03bf0ababfedc56c6086479c34649a8fea8b2435b04c4901f3987c66f67c
living-still.png 170df5348f53221de630c7d7b385e6189f53a27baa2f2246ec7df4f379ed2567
```

---

## 2. Final private-integration diagnostic — the decisive result

One bounded attempt was run, recorded, and closed. **No further private-runtime
debugging is authorized.**

Provenance:
`~/Movies/FCPCommandConsole/provenance/disposable-project-bootstrap-0ACBC06B-0E67-44FA-BDF0-16EC31C8A5FD.json`

```
status                    rejected
reason                    project_bootstrap_bounded_observation_exhausted
stage                     loaded_sequence_readiness
expected_class            FFAnchoredSequence
expected_selector         identifier
actual_receiver_state     nil
observation_turns         24
library_open_status       postopen_exact_enrolled_library_verified
sequence_identifier       8F3BF9A7-CA15-4C81-9D0A-F3F1DD22F3A7
project_creation_count    0
import_invocation_count   0
append_invocation_count   0
```

**How far it got:** library opened and verified, the exact project sequence
identified and its stable identifier recorded, the editor container appeared, and
`loadEditorForSequence:` was invoked.

**Where it stopped:** the timeline module never produced a loaded sequence within
24 real seconds. Zero mutations, ever.

**Interpretation.** The private route is *close* but not working. The most likely
remaining cause is that loading a project into the timeline completes only in
response to a real UI action, which this project prohibits automating. Confirming
that would require another investigation cycle, which is explicitly out of scope.

---

## 3. Five real defects found and fixed this session

Each was confirmed by evidence, not assumption, and each moved the failure
strictly deeper with zero mutations throughout. These are recorded because they
are genuinely non-obvious and a future agent would otherwise re-derive them.

**1. The offline suite blocker was a fragment check, not a schema problem.**
`plugin/tests/run-offline-tests` required the literal string `'" != "15"'` in
**all three** patcher scripts. The interrupted work had bumped only
`update-copied-runtime`. Fix: bump `patch-copied-fcp` and `verify-copied-fcp`,
and add the resume-contract verification they were missing.

**2. The resume arm never opened the library.** It called
`ResolveExactEnrolledLibrary`, which requires a library to already be *open*, but
nothing opened one. Fixed by routing it through the same separately admitted
public `NSDocumentController openDocumentWithContentsOfURL:display:completionHandler:`
route the create arm uses. Now proven live.

**3. The owned-clips invariant was inverted.** The contract demanded *zero* owned
clips. `ownedClips` actually holds the event's existing project. Confirmed twice:
live (`__NSCFSet:count=1:elements=FFAnchoredSequence`) and from the event's own
on-disk Core Data catalog, where `ownedClips` (NSSet) has exactly one child of
`ZTYPE = FFAnchoredSequence`.

Note `FCPCCDisposableProjectBootstrapVerifyImportedFixtures` still asserts
`ownedClips.count == 3` after three imports. That function has **never executed**,
and it is wrong: with one project already owned it should expect 4. Latent bug,
left in place because the create arm is unused.

**4. Two pinned contracts targeted the wrong class.** `FFAnchoredSequence` is not
a descendant of `FFAnchoredObject`. Its real chain is:

```
FFAnchoredSequence -> FFMediaState -> FFMedia -> FFBinObject
```

So `displayName` and `identifier`, both pinned to `FFAnchoredObject`, failed
`isKindOfClass:` on every sequence receiver. **This is the same
`fcp_12_3_fixed_contract_receiver_class_mismatch` that stopped the original
bootstrap at `import=0`.** Two contracts were added, read from the pinned Flexo
image with `otool -o -v`:

| Contract | Class | Selector | arm64 | x86_64 |
| --- | --- | --- | --- | --- |
| `sequenceDisplayName` | `FFAnchoredSequence` (own override) | `displayName` | `0xd37bc` | `0x127880` |
| `sequenceIdentifier` | `FFBinObject` (inherited) | `identifier` | `0x272af0` | `0x380e80` |

Method validated by reproducing three existing pins exactly before trusting any
new number: `FFAnchoredObject displayName` → `0xa77f8`/`0xe7260`, `identifier` →
`0xa7a50`/`0xe75d0`, `FFAnchoredSequence primaryObject` → `0xe422c`/`0x13f470`.

**5. The bounded observation loop never waited.** It re-dispatched with
`dispatch_async` and no delay, draining all 24 turns in milliseconds while Final
Cut was still building its UI. Replaced with a one-shot `dispatch_source` timer at
1000 ms/turn. **This fix worked** — it is why the editor container finally
appeared. Note `dispatch_after`, `NSTimer`, and `performSelector:afterDelay:` are
all forbidden by the offline audit, and the audit scans comments too, so do not
name them in source comments.

### Artifact recovery, also completed

The damaged Schema 15 artifact's only defect was a flattened policy file, caused
by an earlier `plutil -extract` run without `-o` overwriting the plist in place.
**Restoring the exact `abb1a7f` policy bytes revalidated the original signature
chain with no re-signing at all**, reproducing the pinned CandidateCDHashFull
exactly. The staged-donor recipe's re-sign step was never needed. The
reconstruction matched the manifest recorded at the original install across all
47,412 entries.

---

## 4. What is preserved and reusable

All of this is on `standalone-app` and has no dependency on Final Cut injection.

| Component | Path | Notes |
| --- | --- | --- |
| Typed models | `service/Models.swift` (512 lines) | `EffectPlan`, `Target`, `EditableProperty`, `CostEstimate`, `RepresentationClass`, `Backend`, `SelectionToken` |
| Effect registry | `registry/effects/*.json` | four effects with full parameter schemas, ranges, aliases |
| Plan schema | `schemas/effect-plan.schema.json` | |
| Transform math | `service/TransformMath.swift` | rotate/zoom keyframes, easing, anchor compensation — **tested** |
| Old-TV composition | `service/OldTelevisionComposition.swift` (356 lines) | |
| Living-still composition | `service/LivingStillComposition.swift` (315 lines) | |
| FFmpeg renderer | `service/OverlayAdapter.swift` (186 lines) | closed adapter, constant tool paths, **proven to emit alpha-preserving ProRes 4444** |
| Planner / validator | `service/Planner.swift`, `SchemaValidator.swift`, `Registry.swift` | ambiguity handling, fail-closed |
| Cost policy | `service/CostPolicy.swift` | monthly ceiling, approval gating |
| Provenance / hashing | `service/Provenance.swift`, `Hashing.swift`, `PathPolicy.swift` | |
| Job orchestration | `service/JobCoordinator.swift`, `CommandSession.swift` | idempotency |
| Tests | `Tests/FCPCommandConsoleTests` | 52 passing |

`swift build` and `swift test` both succeed on `standalone-app` right now.

**Do not force the private runtime into the new architecture.** `plugin/` and
`Scripts/` belong to the archived experiment.

### Package layout

`Package.swift` (swift-tools-version 6.0, macOS 14+) defines:
- `FCPCommandConsoleCore` library ← `service/`
- `fcpcommandconsole` executable ← `Sources/FCPCommandConsole`
- `fcpcommandconsole-planner-helper` executable
- `FCPCommandConsoleTests` test target

A SwiftUI app target has **not** been added yet. That is the next step.

---

## 5. FCPXML — verified facts for the next agent

FCPXML generation is now explicitly permitted for files the user imports
manually. These facts came from the DTDs shipped inside Final Cut Pro itself, so
they are authoritative for this exact install.

**DTD location:**
```
/Applications/Final Cut Pro.app/Contents/Frameworks/Interchange.framework/Versions/A/Resources/
```
Versions shipped: `FCPXMLv1_0.dtd` … `FCPXMLv1_13.dtd`, `FCPXMLv1_14.dtd`.
**Target 1.13.** Read the DTD directly rather than trusting web examples.

**Verified element definitions:**

```
<!ELEMENT transition (filter-video?, filter-audio?, (%marker_item;)*, metadata?, reserved?)>
<!ATTLIST transition name CDATA #IMPLIED>
<!ATTLIST transition offset %time; #IMPLIED>
<!ATTLIST transition duration %time; #REQUIRED>
```
`filter-video` is **optional** — a bare `<transition>` is valid and is the
simplest path for a default cross dissolve. Try that before chasing effect uids.

```
<!ELEMENT adjust-transform (param*)>
<!ATTLIST adjust-transform position CDATA "0 0">
<!ATTLIST adjust-transform scale CDATA "1 1">
<!ATTLIST adjust-transform rotation CDATA "0">
<!ATTLIST adjust-transform anchor CDATA "0 0">
<!ATTLIST adjust-transform enabled (0 | 1) "1">
```

```
<!ELEMENT param (fadeIn?, fadeOut?, keyframeAnimation?, param*)>
<!ELEMENT keyframeAnimation (keyframe*)>
<!ELEMENT keyframe EMPTY>
<!ATTLIST keyframe time %time; #REQUIRED>
<!ATTLIST keyframe value CDATA #REQUIRED>
<!ATTLIST keyframe interp (linear | ease | easeIn | easeOut) "linear">
<!ATTLIST keyframe curve (linear | smooth) "smooth">
```

```
<!ELEMENT effect EMPTY>
<!ATTLIST effect id ID #REQUIRED>
<!ATTLIST effect uid CDATA #REQUIRED>
```

**Unfinished thread.** I was locating the built-in Cross Dissolve `uid` when the
session was cut. Cross Dissolve is *not* a Motion template — searching for
`*Cross Dissolve*` under the app returns nothing. Motion-template transitions do
exist at:
```
/Applications/Final Cut Pro.app/Contents/PlugIns/MediaProviders/MotionEffect.fxp/Contents/Resources/Templates.localized/Transitions.localized/
```
(e.g. `Styles.localized/Dissolve Smooth.localized/Dissolve Smooth.motr`). Flexo
contains `FFTransition` and `FFTransition_OpticalFlow` strings, so built-in
transition identifiers follow an `FFTransition_*` pattern. **Recommended: try the
bare `<transition>` element first — the DTD says `filter-video` is optional, which
likely yields the default cross dissolve without needing any uid.**

Time values are rationals, e.g. `1001/30000s`. Be frame-accurate.

---

## 6. Apple's supported APIs — what is and is not possible

This is the most important architectural finding. It was determined by dumping
`ProExtensionHost.framework` from this exact build, not from documentation.

**Workflow Extensions cannot mutate the timeline.** The complete `FCPXTimeline`
surface is:

```
activeSequence          read
playheadTime            read
sequenceTimeRange       read
movePlayheadTo:         the only write
addTimelineObserver: / observeActiveSequenceChanged: / observePlayheadTimeChanged:
```

The object model — `FCPXHost` → `FCPXLibrary` → `FCPXEvent` → `FCPXProject` →
`FCPXSequence` — is read-only traversal. `FCPXHost.timeline` is declared `R`
(readonly). There is no insert, append, apply-effect, or add-transition.

**Therefore:** the only supported write path into Final Cut Pro is **FCPXML the
user imports**. That is exactly what this project now does. Do not spend time
looking for a supported API to mutate the timeline directly; it does not exist.

---

## 7. External documentation

### Apple, official

| Topic | URL |
| --- | --- |
| FCPXML reference | https://developer.apple.com/documentation/professional-video-applications/fcpxml-reference |
| FCPXML root element | https://developer.apple.com/documentation/professional-video-applications/fcpxml |
| Legacy FCPXML DTDs | https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/LegacyDTDsFinalCutPro/Introduction/Introduction.html |
| Workflow Extensions | https://developer.apple.com/documentation/professional-video-applications/workflow-extensions |
| Building a Workflow Extension | https://developer.apple.com/documentation/professional-video-applications/building-a-workflow-extension |
| Interacting with the FCP Timeline | https://developer.apple.com/documentation/professional_video_applications/workflow_extensions/interacting_with_the_final_cut_pro_timeline |
| `ProExtensionHostSingleton()` | https://developer.apple.com/documentation/professional_video_applications/proextensionhostsingleton() |
| FxPlug | https://developer.apple.com/documentation/professional-video-applications/fxplug |
| Effect template for Final Cut Pro | https://developer.apple.com/documentation/professional-video-applications/create-an-effect-template-for-use-in-final-cut-pro |
| Preparing plug-ins for Final Cut Pro | https://developer.apple.com/documentation/professional-video-applications/preparing-plug-ins-for-use-in-final-cut-pro |
| FxPlug SDK download | https://developer.apple.com/download/more/?=FXPlug |

**Apple's docs pages are JavaScript-rendered.** `WebFetch` returns only the title.
Use `WebSearch`, or fetch the DTDs from the local app, which is better evidence
anyway.

There is **no** public Apple documentation for Final Cut's private internals
(`Flexo`, `PEAppController`, `FFAnchoredSequence`). Everything in the archived
integration came from static binary inspection.

### Reference repositories

The user pre-identified these. Do **not** start an open-ended GitHub search.
Inspect lightweight first; clone only what directly helps. Record what you use in
`docs/REFERENCE_LOCK.json` and `docs/REPOSITORY_AUDIT.md` with exact commit,
license, and whether code was copied, adapted, invoked, or merely studied.

Highest priority: `elliotttate/SpliceKit`, `Comfy-Org/ComfyUI`,
`BrokenSource/DepthFlow`, `akatz-ai/ComfyUI-Depthflow-Nodes`,
`AEmotionStudio/ComfyUI-FFMPEGA`, `0xsline/OpenChatCut`.

Also useful: `WyattBlue/auto-editor` (FCPXML export patterns),
`browser-use/video-use`, `Memories-ai-labs/vea-open-source`,
`CommandPost/CommandPost`, `elliotttate/finalcutpro-mcp`, `OpenCut-app/OpenCut`,
`remotion-dev/remotion` (audit license first).

Effects and compositing: `NatronGitHub/Natron`, `NatronGitHub/openfx-misc`,
`NatronGitHub/openfx-gmic`, `gl-transitions/gl-transitions` (audit each
transition's license before porting), `MetalPetal/MetalPetal`.

Future segmentation and tracking: `facebookresearch/sam2` (CUDA-oriented, likely
unsuitable for this Mac), `eisneim/sam2.1_mlx` (Apple Silicon path),
`facebookresearch/co-tracker`.

`docs/REFERENCE_LOCK.json` already exists from earlier work — update it, do not
discard it.

---

## 8. Immediate next steps

Steps 1–5 of the user's execution order are **done**. Resume at step 6.

1. ~~Run the final native-integration test~~ — done, section 2.
2. ~~Record the result~~ — done.
3. ~~Commit and archive the private-integration state~~ — done, `9d8b680` + tag.
4. ~~Create a clean standalone-app branch~~ — done.
5. ~~Confirm 52 tests pass~~ — done.
6. **Add a SwiftUI app target** to `Package.swift` (or an Xcode project if that is
   faster) depending on `FCPCommandConsoleCore`.
7. Media loading, drag-and-drop, preview.
8. Targeted rotate/zoom using the existing tested transform math.
9. **FCPXML export + package creation.** Highest value. Start here if time is
   short — it is the capability that makes everything else useful.
10. **Manually test the natural dissolve FCPXML with the user first.** It has the
    clearest expected Final Cut representation, so it is the best first
    confirmation. Ask for one concrete action and wait.
11. Layered old-TV export.
12. Living still via DepthFlow or native fallback.
13. New tests, launch and import instructions, `docs/NEXT_CLAUDE_PROMPT.md`.

### Representation taxonomy

`RepresentationClass` in `service/Models.swift` currently has three cases
(`fcp_native`, `generated_asset_plus_fcp_native`, `external_render_required`).
The user's taxonomy has five. Extend it, keeping backward-compatible decoding:

```
fcpxml_native | layered_media | motion_template |
external_editable_composition | baked_render
```

Rule: **use the most editable practical representation.** Keep ordinary fades,
color changes, placement, and overlays out of baked output. Bake only what
genuinely requires rendered pixels (DepthFlow parallax, complex displacement).

### Export package shape

```
FCPCommandConsole Export/
├── Import into Final Cut.fcpxml
├── Rendered/          Layers/         Source-Compositions/
├── Depth-Maps/        Masks/          Provenance/
├── Plan/effect-plan.json
└── IMPORT-INSTRUCTIONS.md
```

Preserve source media, never overwrite prior exports, use safe paths, and state
which components are editable versus baked.

---

## 9. Constraints that still apply

**Still prohibited:** modifying `/Applications/Final Cut Pro.app`; touching a
production library or user media; silently replacing a live project; assuming an
import succeeded without user confirmation; AppleScript, Accessibility APIs,
simulated input, or coordinate-based UI automation; interfering with SafeSight;
remote Git; secrets in source, logs, or argv.

**Now permitted:** generating `.fcpxml` files the user imports manually, new
events, projects, compound clips, and effect demonstrations; packaging FCPXML
with assets; referencing supplied and generated media through safe local paths.

**Paid services:** $20/month ceiling. Prefer local. Before any paid call, state
provider, estimated cost, and whether media is uploaded, then ask. No paid
provider may become an MVP dependency. **No paid calls were made this session;
total cost $0. No media was uploaded.**

**Scope exclusions:** this is a private local tool. No distribution, App Store,
notarization for others, accounts, telemetry, analytics, hosting, multi-user,
installers, website, or licensing strategy. Licenses are still recorded.

---

## 10. Environment notes that will save time

- **`run-offline-tests` needs a real `ripgrep` binary.** This shell exposes `rg`
  only as a shell function, so the suite aborts before any assertion. A genuine
  binary exists at
  `/Users/marcboyer/.local/share/cursor-agent/versions/2026.06.12-19-59-36-f6aba9a/rg`.
  Prefix with `export PATH="<that dir>:$PATH"`. Only matters for archived
  plugin tests.
- **FFmpeg/ffprobe** are pinned at `/opt/homebrew/bin/ffmpeg` and
  `/opt/homebrew/bin/ffprobe` in `OverlayAdapter`.
- **Full-bundle operations are slow.** Any copied-app transaction takes 15–35
  minutes because it hashes ~38,000 files. Run in background, never poll tightly.
- **`screencapture` fails** in this environment ("could not create image from
  display"), so screenshots are not available for verification.
- **The user cannot use `sudo`** — no admin password by design. Never suggest it.
- Final Cut takes roughly 40–60 seconds to launch before any runtime state
  machine begins.

### If you ever need to run the archived integration again

Sequence: restore the Schema 15 predecessor from the retained
`previous-complete-copy.app` of the most recent `patch-*-update-runtime-*`
directory → run `plugin/patcher/update-copied-runtime` → repin
`expected_copied_cdhash_full` in `Scripts/launch-isolated-fcpcommandconsole` and
`Scripts/tests/run-isolated-launcher-tests` → `--preflight-only` → then
`--launch-resume-disposable-project`. The updater admits **only** an installed
Schema 15 source, so a corrected Schema 16 always requires restoring the
predecessor first. Never edit a pin to accept an artifact.

Terminate the copied app with `kill -TERM <exact pid>` only after proving the pid
via executable path and `lsof`. Never `killall`, `pkill`, `-9`, or anything
touching the stock app.

---

## 11. History

`git log` on any branch has the full record. The private integration is at tag
`archive/splicekit-private-integration`. The prior Phase 1 handoff, its safety
tables, failure guides, and the exact artifact ledger are in that commit's
`docs/HANDOFF.md` if the archaeology is ever needed.

Phase 1 as originally specified was never completed and is now superseded. Its
four workflow rows required manual visual and playback acceptance that no agent
can supply, and native timeline mutation that Apple does not support.
