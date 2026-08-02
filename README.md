# FCPCommandConsole

Private local repository for the FCPCommandConsole v3 core.

The shipped Phase 1 surface is a four-effect, schema-versioned planner and
validator with path/cost/provenance safety, deterministic transform/dissolve
math, and a closed FFmpeg old-TV overlay adapter. It is implemented and tested
without network access or Final Cut Pro control. Native FCP behavior, copied-app
patching, library mutation, DepthFlow models, and perceptual quality remain
unproven.

Runtime output is kept outside Git at `~/Movies/FCPCommandConsole/` in the eight
directories listed in [STATUS.md](STATUS.md). Start with [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), then use `swift run fcpcommandconsole doctor-core`,
`swift test`, and `make overlay-smoke`. The six repositories under `reference/`
are shallow, read-only audit snapshots; their exact commits and licenses are
recorded in [docs/REFERENCE_LOCK.json](docs/REFERENCE_LOCK.json).
