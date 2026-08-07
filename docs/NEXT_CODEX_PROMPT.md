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

## Constraint updates you may be working from a stale copy of

Three project rules changed after this prompt was first written. Check
`docs/HANDOFF.md` §7 for the authoritative list, but in short:

1. **GUI automation of the isolated Final Cut copy and of the reviewed app is
   permitted** (2026-08-05). Every Phase 1 admission and editability pass was
   driven that way. Drive the UI yourself rather than handing worksheets to the
   user — but never record a refusal as a finding without a screenshot of the UI
   state that refused it, because a missed click and a greyed-out control both
   produce "the value didn't change".
2. **Pushing to `origin` is permitted** (2026-08-06). No force-push to a shared
   branch, no history rewriting.
3. **Paid generation is permitted within the configured budget**
   (`service/CostPolicy.swift`).

## Quality outranks structure

Also updated 2026-08-06, and it bears directly on the "keep parameter truth
intact" instruction above — those two are compatible, but the emphasis has
moved.

Parameter truth is about **not lying**: a control is editable only when the
emitted construction has a verified mapping. That still holds exactly as
written.

It is *not* a reason to ship a worse-looking result. If a rendered pass, an
ML-assisted step, or an external compositor produces a materially better image
than a native construction, use it — then record the parameters so it can be
regenerated at a different strength, and state plainly that it is regenerable
rather than Final-Cut-editable. The failure mode is *unrepeatable*, not
*rendered*.

The worked example: Living Still v2 was designed as layered parallax rather than
a depth warp specifically because layers stay editable. Under the current
doctrine that was the wrong call, and it should be reconsidered on the merits of
the resulting image.
