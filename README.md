# FrameSmith

FrameSmith is the product name; the repository, Swift package, bundle, and
legacy command identifiers remain `FCPCommandConsole` for compatibility. Phase
1 is complete at the current **215-test** checkpoint.

It is a real local SwiftUI macOS app for turning admitted stills or movies and
a creative instruction into a schema-versioned FrameSmith plan. It admits media
read-only with source identities, plans against the local registry, offers a
plan-revision inspector, and can generate a **new** Final Cut project package.
It never inspects or mutates an existing Final Cut timeline.

Living Still and Targeted Rotate + Zoom have production standalone emitters.
Their shared plan-driven channels feed both the app preview and FCPXML export,
so a changed admitted control has one construction path. Natural Dissolve and
Old Television are deliberately unavailable in this milestone: they have no
general standalone emitter yet, and the catalog presents the same explicit
reason in preview and export rather than implying a partial implementation.

The inspector exposes only registry-declared live controls. It distinguishes
runtime/approximate edits from invariant and unsupported values, validates
revisions atomically, and supports reset/reset-all to the plan baseline. Living
Still's color construction is only the captured Saturation 25 adapter: it is
indicative, not arbitrary color grading or perceptual calibration. Easing is
read-only where no emitted FCPXML representation has been established.

## Build and verify

```sh
swift test
make test
swift build -c release
make install-app
make launch-app
```

At this checkpoint, `swift test` and `make test` pass all 215 tests; `make test`
also runs the core registry/schema/forbidden-pattern audit. Installing or
launching an app is a separate local-artifact step, not proof that a previous
installed copy is current.

## Outputs and evidence boundary

`Save Local Plan Package` writes an inert, byte-verified package under
`~/Movies/FCPCommandConsole/exports/local-plan-packages/` by default. It copies
admitted media and plan/provenance metadata, but it is not FCPXML, not an effect
render, and is not claimed importable by Final Cut.

Standalone FCPXML export is different: after registry validation, admitted
local-media checks, emitter availability, and the version-scoped Final Cut
semantic profile, it stages and publishes a new project package. The profile is
specific to Final Cut 12.3 (build 450152); evidence remains bounded to the
admitted constructions and does not establish broad visual quality, arbitrary
parameter mappings, or all future Final Cut versions.

See [STATUS.md](STATUS.md), [docs/PARAMETER_LIVENESS.md](docs/PARAMETER_LIVENESS.md),
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), and
[docs/POST_PHASE1_ROADMAP.md](docs/POST_PHASE1_ROADMAP.md).
