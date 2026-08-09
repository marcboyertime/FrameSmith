# FrameSmith

FrameSmith is the product name; the repository, Swift package, bundle, and
legacy command identifiers remain `FCPCommandConsole` for compatibility. Phase
1 is complete at the current **324-test** checkpoint.

It is a real local SwiftUI macOS app for turning admitted stills or movies and
a creative instruction into a schema-versioned FrameSmith plan. It admits media
read-only with source identities, plans against the local registry, offers a
plan-revision inspector, and can generate a **new** Final Cut project package.
It never inspects or mutates an existing Final Cut timeline.

All four effects—Living Still, Targeted Rotate + Zoom, Natural Dissolve, and
Old Television—have production standalone emitters. Their shared plan-driven
construction descriptors drive FCPXML export; the current visual viewer renders
only Living Still and Targeted Rotate + Zoom single-media transform, opacity,
and color channels. It does not render Natural Dissolve's two-clip transition
descriptor or Old Television's connected overlay descriptor. Natural Dissolve
and Old Television were admitted by real
import on 2026-08-07 only for the earlier one-second (30-frame) dissolve and
Old Television native base construction. The current canonical read-only
12-frame Dissolve route is construction-tested but has not had a fresh
real-Final-Cut import. Old Television's optional admitted-still connected
overlay is likewise construction-tested, without a fresh real-Final-Cut or
perceptual pass; it does not generate FFmpeg, static-grain, or scanline assets.

The inspector exposes only registry-declared live controls. It distinguishes
runtime/approximate edits from invariant and unsupported values, validates
revisions atomically, and supports reset/reset-all to the plan baseline. The
currently shipped Natural Dissolve and Old Television registry presentations do
not yet declare a runtime- or approximate-editable control; an emitter or JSON
field alone is not a liveness claim. Living Still's color construction is only
the captured Saturation 25 adapter: it is indicative, not arbitrary color
grading or perceptual calibration. Easing is read-only where no emitted FCPXML
representation has been established.

## Build and verify

```sh
swift test
make test
swift build -c release
make install-app
make launch-app
```

At this checkpoint, `swift test` reports 324 tests and 0 failures;
`make test` reports `core audit: registry=4 schema=json-ok strict-cards=valid
treatment-contract=strict forbidden-patterns=0 cards=15 (reference_only=10
validated=5)`. Installing or launching an app is a separate local-artifact step,
not proof that a previous installed copy is current.

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
