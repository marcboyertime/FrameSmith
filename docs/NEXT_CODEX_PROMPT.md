# Next implementation prompt

> **Superseded queue warning — 2026-08-08:** the Old Television optional-still
> overlay and Living Still v2 acquisition tasks below are historical. Current
> v2 uses a validated connected rendered-movie layer, not the native/optional-
> still route. The pinned Apple Core ML depth model is acquired, the 20-movie
> production bakeoff passed bounded visual review, and Final Cut 12.3 returned
> the rendered-movie construction over still and movie parents. Start with
> `STATUS.md`; do not re-run the stale acquisition queue.

Phase 1 is complete and all four effects already have production standalone
emitters. The next checkpoint is evidence and decision work, not another
Natural Dissolve or Old Television productionization pass. First run a fresh,
version-scoped real-Final-Cut import for the current canonical 12-frame
Natural Dissolve route, then exercise Old Television's optional admitted-still
overlay path in a fresh real-Final-Cut pass and bounded perceptual review.
Their current construction tests and package/FCPXML evidence do not establish
those results.
Keep the new-project-only boundary: generation never modifies an existing
Final Cut timeline or library.

Keep the existing parameter-truth path intact:

```
registry metadata → validated plan → shared emitter channels → FCPXML export
```

The visual viewer is narrower: it renders only Living Still and Targeted
Rotate + Zoom single-media transform/opacity/color channels, not Natural Dissolve's
transition or Old Television's connected-overlay descriptors.

Keep parameter truth intact. A control is editable only when the emitted
construction has a verified mapping; invariants and unsupported controls remain
read-only. Do not claim arbitrary color calibration, perceptual color quality,
or an easing representation that has not been evidenced. Preserve atomic
revision/reset behavior, admitted-media checks, version-scoped capability
decisions, non-overwrite output, source hashes, and schema validation.

After the overlay evidence, make the Living Still v2 acquisition decision before
any implementation: all ten bakeoff classes are measured, Vision two-plane
parallax was demoted by portrait evidence, and the continuous-warp candidate
leads but is untested because no depth model is installed. Do not fetch a model
or start v2 implementation without that decision. If acquisition is authorized,
test the continuous-warp candidate against the recorded rubric and vetoes before
claiming a render, Final Cut admission, or perceptual result. A layered,
rendered, or ML-assisted path is allowed only when it materially wins on
quality while retaining FrameSmith-level revision data and provenance.

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
