# FrameSmith architecture

## Current production path — 2026-08-21

The current product is a local-first SwiftUI application with a public source
repository. Local media is admitted read-only, planned as schema-v2 effects,
validated against the registry and director-control lock, and prepared for
truthful preview before a new-project export can begin.

```text
local media admission
  -> schema-v2 effect/treatment admission
  -> per-option preview preparation coordinator
  -> sealed native channels or exact rendered movie artifact
  -> shared integer-frame comparison transport
  -> explicit native/prepared-rendered export construction
  -> new-project FCPXML package
```

Rendered preview ownership is per admitted option and construction identity,
not one global movie slot. Preparation is bounded, serial for heavy local
renderers, content-deduplicated, cooperative-cancellation aware, and guarded by
latest-generation ownership. Native and rendered representations are distinct
core enum cases. The comparison UI cannot route a rendered treatment through
the native `EffectPoster` path.

Export never renders. It requires an explicit `StandaloneExportConstruction`;
rendered construction carries the previously previewed `RenderedEffectAsset`
whose file hash, source/context, plan, recipe, geometry, timing, codec, and
video-only facts are revalidated before any output root or staging directory is
created. See `docs/ADMITTED_PREVIEW_ARTIFACT_LIFECYCLE.md` for the complete
contract and `docs/SCHEMA_V3_COMPOSITION_DESIGN.md` for the next design-only
milestone.

## Archived original standalone-planner architecture

> **Current-path notice (2026-08-08):** This page records the original inert-
> planner architecture and is retained for historical context. The production
> standalone FCPXML path, including Living Still v2 and Old Television v2 as
> connected rendered-movie treatments, is documented in `STATUS.md`,
> `docs/editorial-intelligence/IMPLEMENTATION_STATUS.md`, and
> `docs/CONNECTED_RENDERED_MOVIE_ADMISSION_PASS.md`. The native Living Still
> opacity/color and native Old Television overlay requirements below are not v2
> production contracts.

## Scope

The product is a standalone local planner and evidence-preserving package tool.
It is not a Final Cut controller or exporter. Its current boundary is designed
to make local inputs inspectable and reproducible while keeping unverified Final
Cut semantics fail-closed.

## Data flow

```text
Open/drop local file
  -> LocalMediaAdmission (canonical regular file, no symlink, metadata, SHA-256)
  -> explicit local role slots (primary or outgoing/incoming)
  -> optional AspectFitPointMapper target
  -> deterministic parser + registry + schema-2 PlanValidator
  -> EffectPlanAdmission + CapabilityGate
  -> source-only UI preview and optional inert LocalPlanPackageBuilder
```

`LocalMediaAdmission` uses ImageIO for stills and modern asynchronous
AVFoundation loading for movies. It rejects directories, FIFOs/devices,
symlinks, unsafe/broad paths, Final Cut application/library paths, undecodable
files, and noncanonical sources. UI work is coordinated by detached workers and
per-role generation tokens; cancellation/newer requests make older results
stale, so they cannot populate a slot later.

`LocalMediaSelection` distinguishes `primary` from dissolve `outgoing` and
`incoming` roles. Its `SelectionToken` intentionally says local-media preview,
with no Final Cut spine or adjacency assertion. `PlanValidator` admits that
origin for local planning only. `CapabilityGate` denies every FCPXML capability
for it even if future semantic evidence exists.

## Domain boundaries

| Domain | Current responsibility | Explicitly not proved |
| --- | --- | --- |
| Registry/planner | Four typed workflows, bounded parameters, schema v2 validation | Final Cut acceptance |
| Point mapper | Aspect-fit view point ↔ normalized `[0,1]` target, letterbox rejection | Final Cut coordinate convention |
| Source preview | Shows original local media only | Effect preview/render |
| Capability gate | Quarantine, local-only/inert allowance, FCPXML denial reasons | FCP import/export semantics |
| Local package | Hash-checked, non-overwriting inert archival copy | Final Cut package/importability |
| Round-trip spike | Reduced DTD/syntax evidence and manual evidence record | Successful Final Cut transition/export |

## Schema and capability model

The only emitted plan schema is `2.0`. Canonical representation classes are
`fcpxml_native`, `layered_media`, `motion_template`,
`external_editable_composition`, and `baked_render`. Legacy schema 1.0 inputs
and old representations are quarantine results, never silent upgrades.

FCPXML evidence is granular, not a global flag. Required contracts vary by
effect: natural dissolve requires asset admission plus cross-dissolve
transition; targeted transform requires asset admission plus transform
keyframes; Living Still also needs opacity and native color; Old Television
needs opacity, native color, and connected overlays. A successful dissolve
probe may admit only asset admission and cross dissolve.

`cross_dissolve_transition` was `bare_dissolve_transition` until the round-trip
probes disproved the bare form. It covers four conditions that must hold
together — a real `<effect>` resource, a `<filter-video>` referencing it, the
transition offset at `cut − duration/2`, and butt-joined adjacent clips with
source beyond the joint. Two of the four failure modes produce DTD-valid
documents that Final Cut silently rewrites, which is the concrete reason
validity is not evidence.

## Package layout and safety

`LocalPlanPackageBuilder` validates a current admission, exact plan/slot
identities, the inert-package gate, output root, operation target, current file
type, and SHA-256 immediately before/copy/after each media copy. It stages in a
unique sibling and atomically publishes an exact UUID directory only after all
checks pass. Failure removes only that staging directory. The manifest records
relative paths, hashes, byte counts, media roles/types, operation/schema, and
`containsFCPXML=false`, `containsEffectRender=false`, and
`finalCutCompatibility=unverified`.

Runtime roots and reference snapshots remain useful scope/reproducibility
defaults, but they do not prove product or Final Cut behavior.
