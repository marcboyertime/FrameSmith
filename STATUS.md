# FCPCommandConsole status

Checkpoint refreshed 2026-08-03 from local evidence. The code checkpoint before
this documentation refresh is commit `406edb8` on branch `standalone-app` with
a clean working tree.

## Verified implementation and local app facts

| Item | Evidence |
| --- | --- |
| Core build | `swift build` passed at checkpoint `406edb8` |
| Test suite | `swift test`: 79 tests, 0 failures |
| Standalone app | `/Users/marcboyer/Applications/FCPCommandConsole.app` |
| Bundle identity | `com.marcboyer.FCPCommandConsole` |
| Signature | `codesign --verify --deep --strict` passed |
| Bundled resources | registry and schema resources present in the installed app |
| Process snapshot | PID `6515` was observed for the installed app; PIDs are drift-prone and must be rechecked |
| Current plan schema | exactly `2.0` |

The SwiftUI app is a local-media planning surface. It admits read-only local
movies/stills, computes SHA-256 identities, presents source-only previews,
collects an optional aspect-fit normalized point, plans against the local
registry, and can save an inert local plan/media package. It does not render an
effect or control Final Cut.

## Current plan taxonomy and gates

Schema 2.0 encodes only these representation values:

- `fcpxml_native`
- `layered_media`
- `motion_template`
- `external_editable_composition`
- `baked_render`

Schema 1.0 and the old raw values `fcp_native`,
`generated_asset_plus_fcp_native`, and `external_render_required` are
quarantined. They may receive a suggested migration class, but cannot become a
current executable/previewable plan; they must be replanned and validated as
schema 2.0. Unknown schema versions fail closed.

`CapabilityGate` is central. Current v2 plans may be used for local-only
preview and inert payload-neutral packaging. FCPXML preview/export remains
blocked without granular manual semantic contracts, and local-media tokens also
never establish Final Cut selection/spine/adjacency evidence. Contract evidence
is effect-scoped: asset admission, bare dissolve, transform keyframes, opacity
keyframes, native color adjustment, and connected overlay layers are separate.

## Inert package fact

`LocalPlanPackageBuilder` creates a non-overwriting UUID directory under
`~/Movies/FCPCommandConsole/exports/local-plan-packages/` by default. It stages
beside the target, checks safe roots and exact admitted slots, rehashes each
source before/copy/after, and publishes only on a complete match. A package
contains `EffectPlan.json`, `Manifest.json`, `Provenance.json`, `README.txt`,
and copied `Media/` files. It contains no `.fcpxml`, effect render, shell
command, or Final Cut compatibility claim.

## Final Cut evidence boundary

Final Cut Pro installed version: **12.3, build 450152**. This is environment
metadata, not acceptance evidence. Phase 1 remains **incomplete: 0/4 Final Cut
workflows accepted**.

The immutable reduced v2 round-trip package is:

`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/CA7D0733-A435-498E-BD82-149CFF863FC3`

Its syntax/DTD package evidence passed, but every manual Final Cut semantic
status remains unknown. The predecessor v1 import crashed during `asset-clip`
import:

- report: `/Users/marcboyer/Library/Logs/DiagnosticReports/Final Cut Pro-2026-08-03-082455.ips`
- incident: `42DFFCF1-9E45-41DA-992F-ADB212422B07`
- predecessor operation: `A78B1B9D-60D7-4CD8-960B-FA9104C301E7`

The sole next manual action is one controlled import of that exact immutable v2
package into Final Cut 12.3/450152, followed by an export/readback of the bare
dissolve result. Stop immediately on any error, crash, alert, missing media,
missing transition, or export normalization discrepancy; record evidence before
any retry. Even success admits only **asset admission + bare dissolve**. Do not
extend it to transform, opacity, color, or connected-overlay semantics.
