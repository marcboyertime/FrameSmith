# FCPCommandConsole v3 architecture

Phase 1 ships a deterministic, in-process core. It has no network runtime and
does not launch, patch, automate, or mutate Final Cut Pro. The four effect
definitions are JSON registry data; plans are typed, versioned, validated, and
safe to inspect before any future execution boundary.

The Phase 1 effect domain is exactly `native.targeted_rotate_zoom`,
`look.old_television`, `transition.natural_dissolve`, and `motion.living_still`.
The future FCP lane is intentionally constrained to a minimal SpliceKit-derived
profile. It must operate on exactly one canonically verified disposable library,
with isolated copied-app preferences. A least-privilege pinned patcher must
produce an entitlement/signature diff before any copied app is considered. A
persistent `SelectionToken` carries the timeline revision and selection fields
across the plan/execute boundary. Mutation, when separately authorized, is a
main-thread atomic operation with a UUID-named, verified transaction and undo
record. Stage 4 has an explicit go/no-go gate based on those artifacts.

There is no responder/dialog fallback and no FCPXML fallback in this architecture.
Neither is a substitute for verified native editability. DepthFlow is a typed
status stub only; generated overlays are produced by a closed FFmpeg adapter
under the Movies runtime root.

## Data flow

`request text -> deterministic parser -> registry lookup -> EffectPlan -> runtime policy validator -> (future) executor`

The current executor boundary stops after validation. Path, budget (with
independent provider and operation-scoped media-upload approvals),
provenance/idempotency, rollback records, and generated-overlay verification are
available without touching FCP.

Reference concepts are derived from the local SpliceKit snapshot (MIT, commit
locked in `docs/REFERENCE_LOCK.json`); no upstream implementation is copied.
