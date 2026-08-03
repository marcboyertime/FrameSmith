# FCPCommandConsole handoff

Refreshed 2026-08-03. This is the standalone product handoff. Read it before
changing code, running a manual Final Cut probe, or interpreting a package.

## 1. Current checkpoint

| Item | Value |
| --- | --- |
| Repository | `/Users/marcboyer/Developer/FCPCommandConsole` |
| Working branch | `standalone-app` |
| Implementation checkpoint before this documentation refresh | `406edb8` — `Add inert local plan packaging` |
| Prior foundational commits | `51209bb` schema-v2 taxonomy; `98d1340` granular capability evidence; `184f003` standalone local-media app |
| Checkpoint worktree | clean before this documentation-only refresh |
| Build/test evidence | `swift build` passed; `swift test` passed 79 tests, 0 failures |
| App bundle | `/Users/marcboyer/Applications/FCPCommandConsole.app` |
| Bundle ID | `com.marcboyer.FCPCommandConsole` |
| App signature | `codesign --verify --deep --strict` passed |
| Live process snapshot | PID `6515` was observed; this is drift-prone and must not be treated as current without rechecking |
| Final Cut environment | Final Cut Pro 12.3, build 450152 |

The current product is a **standalone local-media planner and inert package
tool**. It does not control Final Cut, write an FCP library, automate a UI,
render an effect, or claim an editable Final Cut result.

## 2. What is implemented and verified

### Schema and planner

The only emitted plan schema is `2.0`. The only canonical representation values
are:

- `fcpxml_native`
- `layered_media`
- `motion_template`
- `external_editable_composition`
- `baked_render`

Registry mapping: targeted rotate/zoom, natural dissolve, and Living Still use
`fcpxml_native`; Old Television uses `layered_media`. This is typed planning
intent only, not Final Cut acceptance.

Schema `1.0` and raw values `fcp_native`,
`generated_asset_plus_fcp_native`, and `external_render_required` are
quarantined. They can have an explanatory suggested mapping but cannot silently
be upgraded into a current plan, previewed, packaged, exported, or executed.
Replan and validate a schema-2 plan. Unknown schema versions fail closed.

### Capability model

`service/CapabilityGate.swift` is the authority for capability decisions. It
allows current v2 plans for local-only source preview and inert payload-neutral
packaging. It denies FCPXML preview/export whenever manual semantic contracts
are missing. It also denies FCPXML for `LocalMediaSelection` regardless of a
semantic profile because local files do not establish Final Cut selection,
spine, revision, or adjacency evidence.

Semantic evidence is granular:

| Contract | Why it is separate |
| --- | --- |
| asset admission | Source/media resource acceptance |
| bare dissolve transition | A plain transition semantic |
| transform keyframes | Position/scale/rotation keyframe behavior |
| opacity keyframes | Opacity/fade behavior |
| native color adjustment | Color-control behavior |
| connected overlay layers | Layer placement/compositing behavior |

Natural dissolve needs asset admission plus bare dissolve. Targeted rotate/zoom
needs asset admission plus transform keyframes. Living Still additionally needs
opacity and native color. Old Television needs opacity, native color, and
connected overlays. A successful bare-dissolve test must not unlock any other
workflow.

### Local media app

`FCPCommandConsoleApp` is a SwiftUI macOS executable product. It has command
text, role slots, Open panels, file drop, source metadata, source-only
`VideoPlayer`/still preview, aspect-fit point selection, plan summary,
FCPXML-disabled explanation, cancellation, and error state.

`service/LocalMediaAdmission.swift` performs read-only admission:

- canonical absolute regular local movie/still only;
- rejects symlinks, directories, FIFOs/devices, unsafe/broad paths, Final Cut
  application/library paths, unreadable inputs, and undecodable content;
- hashes source bytes without modifying them;
- uses ImageIO for still dimensions and asynchronous AVFoundation properties for
  movies (duration/frame rate/audio/video dimensions).

Admission workers are detached from the main actor. Per-role generation tokens
in `service/LocalMediaOperationGeneration.swift` ensure a cancelled or older
worker cannot later overwrite a slot. The same pattern keeps cancelled package
work from publishing a stale app result.

`service/LocalMediaSelection.swift` has explicit roles:

- one-source workflows: `primary` only;
- dissolve: `outgoing` and `incoming` only, in that order.

Tokens use `timelineID = local-media-preview`, with `isSpine=false` and
`adjacent=false`. That is intentional evidence honesty, not a validation bug.
`service/Planner.swift` permits these tokens for local planning while
`CapabilityGate` retains the FCPXML block.

`service/AspectFitPointMapper.swift` maps view points to normalized targets and
back. It rejects nonfinite input, invalid geometry, letterbox space, and outside
clicks. It is separately tested and is not proof of Final Cut's coordinate
convention.

### Inert local packages

`service/LocalPlanPackage.swift` provides `LocalPlanPackageBuilder`. It accepts
only a current v2 admission and the exact `LocalMediaSelection` whose token and
source identities match the plan. It asks CapabilityGate for
`inertPayloadNeutralPackage` before writing.

Default output root:

`~/Movies/FCPCommandConsole/exports/local-plan-packages/`

For each operation UUID it creates a sibling unique staging directory, validates
the output root, refuses an existing target, checks each source is still a
canonical regular non-symlink file, hashes it immediately before copy, hashes
the copied file, hashes the source again, and atomically publishes only when all
hashes match. The source is not altered. Failure removes only the exact staging
directory.

Each package contains:

```text
<operation UUID>/
  EffectPlan.json
  Manifest.json
  Provenance.json
  README.txt
  Media/<role>-<sanitized basename>
```

It contains no `.fcpxml`, effect render, shell command, or claim of Final Cut
editability. Manifest fields include relative paths, SHA-256, bytes, media
role/type, schema version, operation, `containsFCPXML=false`,
`containsEffectRender=false`, and `finalCutCompatibility=unverified`.

## 3. Current commands and evidence

Run from the repository root:

```sh
git status --short
git rev-parse --abbrev-ref HEAD
swift build
swift test
make install-app
codesign --verify --deep --strict /Users/marcboyer/Applications/FCPCommandConsole.app
plutil -extract CFBundleIdentifier raw /Users/marcboyer/Applications/FCPCommandConsole.app/Contents/Info.plist
test -f /Users/marcboyer/Applications/FCPCommandConsole.app/Contents/Resources/registry/effects/native.targeted_rotate_zoom.json
test -f /Users/marcboyer/Applications/FCPCommandConsole.app/Contents/Resources/schemas/effect-plan.schema.json
make launch-app
pgrep -fl '/FCPCommandConsole.app/Contents/MacOS/FCPCommandConsoleApp' || true
git diff --check
```

Expected app identifier is `com.marcboyer.FCPCommandConsole`. `Scripts/install-app`
builds release, stages the exact bundle under `~/Applications`, copies registry
and schema resources, ad-hoc signs with `codesign --force --deep --sign -`,
verifies `--deep --strict`, verifies ID/resources, then swaps only an existing
bundle with the same ID. It preserves a recoverable hidden backup when bytes
differ and skips another backup for byte-identical output.

Known backups from this checkpoint sequence include:

- `/Users/marcboyer/Applications/.FCPCommandConsole.app.backup.20260803090251`
- `/Users/marcboyer/Applications/.FCPCommandConsole.app.backup.20260803091103`

Do not delete backups casually. They are recoverable evidence of exact prior
owned bundles.

## 4. Final Cut crash and reduced v2 gate

The prior v1 round-trip attempt crashed during Final Cut `asset-clip` import.
Preserve these exact facts:

| Item | Value |
| --- | --- |
| Crash report | `/Users/marcboyer/Library/Logs/DiagnosticReports/Final Cut Pro-2026-08-03-082455.ips` |
| Incident ID | `42DFFCF1-9E45-41DA-992F-ADB212422B07` |
| Predecessor operation | `A78B1B9D-60D7-4CD8-960B-FA9104C301E7` |
| Crash phase | importer `asset-clip` |
| Final Cut build | 12.3 / 450152 |

The reduced v2 package is immutable for the next manual test:

`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/CA7D0733-A435-498E-BD82-149CFF863FC3`

It includes `FCPCommandConsole-RoundTrip-Spike.fcpxml`, media, manifest, plan,
provenance, README, and `evidence.json`. Its syntax/DTD package checks passed;
that does **not** establish Final Cut import, transition, export, or semantic
acceptance. All manual semantic evidence is unknown.

The next manual gate is exactly one operation:

1. On Final Cut 12.3 build 450152, manually import that exact immutable v2
   package.
2. Inspect whether the bare dissolve and media appear as expected.
3. Export/read back the result and compare it to the recorded expectation.
4. Stop on the first error, crash, alert, missing media, missing transition, or
   normalized-export discrepancy. Capture the outcome before any retry.

If and only if it succeeds, admit **asset admission + bare dissolve** for that
specific evidence profile. Keep transform, opacity, color, and overlay probes
separate and blocked. Phase 1 remains 0/4 Final Cut-accepted until workflow
specific manual evidence exists.

## 5. Failure modes and fixes

| Symptom | Meaning | Correct response |
| --- | --- | --- |
| App blank or exits | Wrong/unsigned bundle or missing resources | Re-run `make install-app`; verify codesign, ID, registry/schema files |
| Installer refuses replacement | Existing bundle has a different identifier | Do not overwrite it; inspect it and choose a distinct owned target only with authority |
| Admission rejects a file | It is a symlink, nonregular, unsafe, Final Cut path, or undecodable | Use the canonical real local file; never weaken admission |
| Old media appears after a newer drop/Cancel | This would be a stale UI result | Inspect generation-token/task handling; older results must be ignored |
| Package collision | Operation UUID target exists | Re-plan to get a new operation; do not overwrite evidence |
| Package stale hash/nonregular failure | Source changed or no longer matches admission | Re-admit and re-plan; preserve the old evidence |
| Package staging remains | A failure/cancellation cleanup defect | Inspect only that UUID staging directory and fix cleanup; never broad-delete the output root |
| FCPXML button disabled | Correct CapabilityGate behavior | Read the gate reason; do not duplicate or bypass it |
| v2 import crashes/fails/misses transition | Manual semantics not established | Stop immediately, preserve package/crash/log evidence, do not retry modified payloads |
| Export differs/normalizes | Final Cut semantics differ from the package assumption | Record exact difference; treat contract as unknown/failed |
| Final Cut build changes | Existing manual evidence may not apply | Re-identify version/build and re-establish evidence with a new bounded probe |

## 6. Safety-rule review

### Essential failure-prevention boundaries

- Never modify stock `/Applications/Final Cut Pro.app`, source media, or any
  production Final Cut library.
- Do not use AppleScript, Accessibility APIs, keyboard/mouse simulation, or
  coordinate-based UI automation.
- Do not make paid calls, upload media, or push to a remote without explicit
  user authority.
- Keep secrets out of source, logs, shell history, command arguments, and
  packages.
- Use canonical paths, symlink/nonregular rejection, SHA-256, exact identity
  matching, non-overwrite targets, staging publication, and fail-closed gates.
- Treat a DTD pass, source preview, local package, app signature, or test pass
  as implementation evidence only, never as Final Cut workflow acceptance.

### Archived or nonbinding historical restrictions

Copied-app launchers, private runtime injection/patch rules, isolated copied
preferences, and related private-runtime constraints are archived history. They
should not drive standalone implementation or documentation. Do not revive that
route as a shortcut to a Phase 1 claim.

The Movies runtime root and read-only `reference/` snapshots remain useful
scope/reproducibility conventions. They are defaults and audit context, not
evidence that a workflow or Final Cut semantic works.

## 7. Authority and practical autonomy for the next AI

A next AI may autonomously edit focused project files, build/test/install the
standalone app, launch an app process it owns, use terminal tooling, create
synthetic local fixtures, and use network access for focused public research or
local dependency investigation when useful. Preserve current user edits and
report actual commands/results.

That autonomy does not authorize stock Final Cut/source/production-library
changes, UI automation, paid services, media uploads, secrets exposure, or
remote pushes. Research should be evidence-backed; implementation should retain
the non-overwrite/hash/fail-closed boundaries above.

## 8. Prioritized next steps

1. Verify the current branch/state and rerun `swift build`, `swift test`, and
   installed-app signature/resource checks before changing behavior.
2. Carry out the one immutable reduced-v2 manual import/export probe only when
   the owner is ready to observe Final Cut manually. Record either success or
   the first stop condition.
3. If bare dissolve succeeds, encode only the two admitted contracts and keep
   all other workflow capabilities blocked.
4. If it fails, preserve exact evidence and diagnose the reduced package/export
   observation without broadening payload semantics or touching Final Cut by
   automation.
5. After Phase 1 manual evidence is established, begin Phase 2 with reusable
   custom effects, melt, portal, masks, segmentation/tracking, and external
   editable compositions. Each needs its own contracts and probe.

## 9. Code hotspots

| Path | Purpose |
| --- | --- |
| `service/Models.swift` | Schema v2 plan model and legacy quarantine |
| `service/Planner.swift` | Deterministic planning and local-token validation boundary |
| `service/CapabilityGate.swift` | Central local/inert/FCPXML decisions and semantic-contract requirements |
| `service/LocalMediaAdmission.swift` | Read-only ImageIO/AVFoundation admission and cancellable hashing |
| `service/LocalMediaSelection.swift` | Roles, exact counts, local-only token |
| `service/AspectFitPointMapper.swift` | Letterbox-safe target mapping |
| `service/LocalMediaOperationGeneration.swift` | Stale result prevention |
| `service/LocalMediaPlanning.swift` | Plan/admission/selection/capability result |
| `service/LocalPlanPackage.swift` | Inert package construction, root/source/hash/staging checks |
| `Sources/FCPCommandConsoleApp/FCPCommandConsoleApp.swift` | Standalone UI and detached worker coordination |
| `Scripts/install-app` | Staged signed install and backup behavior |
| `service/FCPXMLRoundTripSpike.swift` | Reduced v2 package/evidence; do not turn it into production export |
| `Tests/FCPCommandConsoleTests/LocalMediaTests.swift` | Admission/roles/point/generation tests |
| `Tests/FCPCommandConsoleTests/LocalPlanPackageTests.swift` | Package success/failure cleanup/hash safety tests |

## 10. Completion language

Use precise language. It is correct to say the standalone app, local admission,
schema v2 planner, capability gate, and inert package builder are implemented
and tested. It is not correct to say Final Cut import, export, transition,
transform, editability, source preview effects, or any of the four workflows is
working. Current Final Cut acceptance is **0/4**.
