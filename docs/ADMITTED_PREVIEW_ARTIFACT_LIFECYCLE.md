# Admitted preview-artifact lifecycle

Status: implemented and covered by deterministic core tests on 2026-08-21.

## Why this boundary exists

Rendered effects have neutral native scalar channels because their visible
result lives in generated pixels. Showing those channels or an untreated source
as A/B/C would be a false comparison. Rendering again during export could also
produce bytes different from what the user approved.

FrameSmith therefore uses two admissions:

1. `AdmittedTreatmentExecution` binds structure, plan, media contexts,
   registry, cards, contract, and native channels.
2. `AdmittedTreatmentPreview` binds that exact execution to either its admitted
   native channels or one exact `RenderedEffectAsset`.

The preview artifact records option identity, editorial-structure fingerprint,
treatment and execution signatures, registry digest, typed input snapshot,
preview profile, representation, content digest, and its own artifact digest.
The rendered asset additionally binds file SHA-256, source SHA-256,
construction/recipe identity, output geometry, frame rate/count/duration,
ProRes profile/pixel format, and video-only status.

## Lifecycle and state ownership

```text
admitted option
  -> idle
  -> queued
  -> preparing
  -> ready(admitted native channels or exact rendered bytes)
     | failed(reason)
     | cancelled
```

`TreatmentPreviewPreparationCoordinator` is an actor independent of SwiftUI.
It owns state per option, admits at most three comparison selections, hashes
render construction identity for cache/deduplication, and serializes heavy local
render work. Each request receives a generation token. A task that completes
after deselection, input drift, or replacement may contribute already durable
validated bytes to the content cache, but it cannot publish `ready` for stale
ownership.

One failure changes only its option. Authoritative input or plan drift cancels
ownership and forces new admission. Missing/deleted/mutated files and changed
source context, plan, recipe, timing, geometry, registry, contract, or structure
fail closed.

## Truthful comparison

`TreatmentComparisonTileDescriptor` has explicit native and rendered cases.
SwiftUI chooses `EffectPoster` only for native channels. Rendered tiles request
the exact frame from the admitted movie with zero tolerance; they show progress
or refusal rather than a previous frame or untreated source.

`TreatmentComparisonTransport` owns one integer frame index, frame rate, frame
count, play state, scrub, and wrap. Every tile resolves the same requested frame
index. The current admitted comparison scope is 120 frames at 30 fps.

## Export contract

Export accepts `StandaloneExportConstruction.native` or
`.rendered(RenderedEffectAsset)`. A rendered emitter plus `.native` refuses
before output-root creation. The builder never calls `prepareRenderedAsset`.
The app and CLI explicitly prepare first, admit/preview, and then pass those
same bytes to export. Export revalidates and hashes them before staging and
after copying.

## Continuous controls

`ParameterDraftCommitState` keeps slider ticks out of authoritative treatment
history. A drag may update many local draft values; gesture completion emits at
most one patch. Rejected commits restore authoritative display state, and input
drift or teardown discards drafts. Render preparation begins only after an
accepted authoritative revision.

## Evidence boundary

Core tests prove identity, drift refusal, representation routing, shared frame
resolution, three-option bounds, deduplication, cancellation, stale durable
classification, latest-generation ownership, no-hidden-render export, and
single-commit slider bursts. Installed visual observation and Final Cut returned
evidence remain separate evidence classes.
