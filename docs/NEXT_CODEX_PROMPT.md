# Next implementation prompt

Phase 1 is complete. Work on the next milestone: productionize **Natural
Dissolve** and **Old Television** through the existing parameter-truth path:

```
registry metadata → validated plan → shared emitter channels → preview/FCPXML
```

Do not wait for another Phase 1 gate or replace the two unavailable states with
a nominal implementation. Each effect needs a generalized emitter, a shared
preview/export construction, explicit catalog availability, regression tests,
and focused Final Cut evidence appropriate to its semantics. Preserve the
existing new-project-only boundary: generation never modifies an existing Final
Cut timeline or library.

Keep parameter truth intact. A control is editable only when the emitted
construction has a verified mapping; invariants and unsupported controls remain
read-only. Do not claim arbitrary color calibration, perceptual color quality,
or an easing representation that has not been evidenced. Preserve atomic
revision/reset behavior, admitted-media checks, version-scoped capability
decisions, non-overwrite output, source hashes, and schema validation.

Natural Dissolve should use the shared architecture rather than a special
one-off document path. Old Television should do the same for its connected
overlay construction. Keep their Final Cut claims version-scoped and bounded to
returned evidence; neither a source preview, XML/DTD pass, nor a package alone
establishes a quality or import claim.

Living Still v2 remains explicitly out of scope for this milestone. Reconsider
it only under the quality-first doctrine: useful editability is a priority, not
an absolute requirement, and a layered, rendered, or ML-assisted path is
allowed when it wins materially on quality while retaining FrameSmith-level
revision data and provenance.

Start by reading `STATUS.md`, `docs/PARAMETER_LIVENESS.md`,
`docs/HANDOFF.md`, current Git state, and the current test evidence. Work on
`standalone-app`; do not revive stale copied-app or private-runtime assumptions.
