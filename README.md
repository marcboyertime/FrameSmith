# FrameSmith

FrameSmith (repository and bundle identifiers remain FCPCommandConsole) now creates a **new** Final Cut project from admitted local media; it never modifies a timeline. Real emitter-backed preview/export currently cover Living Still and Targeted Rotate + Zoom. Natural Dissolve and Old Television are honestly unavailable pending generalized emitters. Registry controls distinguish exact supported edits, approximate edits, invariants, and unsupported values; Living Still color is indicative only and fixed to captured Saturation 25.

FCPCommandConsole is a private, local macOS planner with a standalone SwiftUI
app. It accepts local stills/movies read-only, creates schema-versioned plans,
and saves inert, byte-verified plan/media packages. It has no network runtime
and does not automate, patch, launch, or modify Final Cut Pro.

The installed app is `/Users/marcboyer/Applications/FCPCommandConsole.app`.
Build/install/launch it with:

```sh
swift test
make install-app
make launch-app
```

The app is explicitly **LOCAL MEDIA PREVIEW ONLY**. Source preview is not an
effect render. FCPXML export is visible but disabled by `CapabilityGate` because
Final Cut semantics, selection evidence, import, export, and editability remain
unverified.

Plans use schema `2.0` and the canonical representations `fcpxml_native`,
`layered_media`, `motion_template`, `external_editable_composition`, and
`baked_render`. Legacy schema/value inputs are quarantined and must be replanned.

`Save Local Plan Package` creates an inert package under
`~/Movies/FCPCommandConsole/exports/local-plan-packages/` by default. It copies
only verified source bytes and metadata; it is not FCPXML, not an effect render,
and is not claimed to be Final Cut importable.

See [STATUS.md](STATUS.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md),
[docs/RUNBOOK.md](docs/RUNBOOK.md), and [docs/HANDOFF.md](docs/HANDOFF.md) for
the current evidence boundary and next manual probe.
