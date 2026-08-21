# Schema-v3 composition core — next-package design

Status: design only. No schema-v3 model, migration, planner, preview graph, or
export graph is implemented in this checkpoint.

## Target flow

```text
locked editorial structure
  -> clip, range, or transition targets
  -> ordered treatment operations
  -> shared preview construction
  -> native and/or rendered output
  -> durable version and export history
```

## Proposed contract

- A graph is rooted in an immutable director-control structure fingerprint.
- Every node has a stable content identity, operation type, typed target,
  enabled state, deterministic order, parameter payload, capability contracts,
  provenance, and preview/output representation.
- Clip/range nodes may stack on one locked clip. Transition nodes target a
  locked edit point and may consume only admitted handle without moving it.
- Reorder and enable/disable produce new graph identities and durable versions;
  they never mutate history in place.
- Channel conflicts are explicit. Operations touching disjoint channels compose
  in order. Operations touching the same native channel require a registered
  deterministic reducer or refuse. Rendered nodes form an ordered pixel
  pipeline and cannot be silently reordered around native nodes.
- Mixed native/rendered graphs declare a construction boundary. Native nodes
  before a rendered boundary become inputs to that render; supported native
  nodes after it remain explicit FCPXML. Unsupported interleavings refuse.
- Graph identity covers the structure fingerprint, ordered node identities,
  target facts, conflict-resolution versions, media contexts, and construction
  profile. Per-node provenance remains independently inspectable.
- Preview preparation reuses `AdmittedTreatmentPreview`: graph output receives a
  graph-level admitted preview artifact bound to the graph identity, exact
  inputs, and native channels and/or prepared rendered bytes.
- Director-control validation runs before preview preparation and again before
  export. Clip order, inclusion, edit points, durations, sync, narration, and
  music structure remain locked unless an exact user-authorized delta exists.
- Imported FCPXML or edit manifests are read-only structure inputs. They do not
  authorize timeline mutation.
- Durable versions record parent version, graph digest, prepared artifacts,
  export package/hash, Final Cut profile, status, and stale/failure reason.

## Migration discipline

Schema-v2 plans remain valid only through their current single-effect runtime.
They are never decoded as graph nodes by guesswork. A future explicit migration
may wrap one exact v2 plan in one graph node only when every field maps without
loss; otherwise it quarantines the plan with a readable reason. Schema-v3 must
ship with independent schema validation, compatibility fixtures, capability
gates, and no broadening of existing Final Cut evidence.

## First implementation slice

Implement the typed graph and validators with one native node and one rendered
node in a locked single-clip fixture, plus a transition-target fixture. Keep the
existing standalone effects and admitted preview lifecycle as adapters. Do not
add a fifth effect, generative provider, upload, paid call, or existing-timeline
mutation.
