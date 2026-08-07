# Codex Integration Specification

## Outcome

Integrate the package as durable, selectively retrieved FrameSmith knowledge and
build toward a bounded treatment-planning layer. Do not dump 153 sources into a
single prompt or pretend that links are runtime capabilities.

## Repository placement

Recommended structure:

```text
docs/editorial-intelligence/
  README.md
  DIRECTOR_CONTROL_CONTRACT.md
  EDITORIAL_PLAYBOOK.md
  SURPRISE_ME_DESIGN.md
  QUALITY_RUBRIC.md
  SOURCE_ATLAS.md
  sources.csv

registry/editorial-techniques/
  motion.*.json
  transition.*.json
  look.*.json
  typography.*.json
  audio.*.json
  safety.*.json

schemas/
  technique-card.schema.json
  treatment-plan.schema.json
```

Keep the root `AGENTS.md` concise. Add only:

- the director-control rule;
- a requirement to read the contract for creative features;
- a requirement to use technique-card provenance and the quality rubric;
- a requirement that preview/export share the same admitted construction.

Reference the longer files instead of embedding them. Codex's documented
`AGENTS.md` discovery has a finite instruction budget, and broad guidance is more
effective when short and accurate.

## Core types

### `EditorialStructureLock`

Machine-checkable snapshot of:

- ordered admitted media identities;
- clip timing, source ranges, retiming, and sync;
- protected narration/music structure;
- user-protected spatial regions;
- explicitly authorized structural deltas, normally none.

Validate before planning, preview, packaging, and export.

### `TechniqueCard`

Provenance-bearing compact craft/implementation record. See the schema guide in
this pack. A card may be `validated`, `experimental`, `reference_only`, or
`unsupported`. Only validated cards whose capabilities and prerequisites pass may
be presented as executable.

### `TreatmentPlan`

Semantic composition of treatment choices:

- locked structure fingerprint;
- user request and preservation rules;
- motion, transition, look/color, typography, sound, and compositing goals;
- chosen technique-card IDs;
- concrete effect operations/render graph;
- parameters;
- backend routing;
- cost/privacy/latency;
- provenance;
- capability and preview-fidelity decisions.

### `TreatmentOptionSet`

One to three admitted alternatives with diversity evidence and a shared
editorial-structure fingerprint. It must never pad the set with fake variants.

## Services

### `EditorialKnowledgeCatalog`

- load and schema-validate cards;
- index by domain, intent, prerequisites, capability status, risk, and source;
- refuse duplicate IDs and unknown fields;
- make source provenance inspectable;
- require explicit versioning for changed claims.

### `TreatmentPlanner`

- interpret treatment intent while preserving original language;
- retrieve a small relevant card set;
- bind cards to admitted capabilities and media evidence;
- build semantic and concrete treatment plans;
- provide refusal reasons for unsupported ideas.

### `TreatmentOptionGenerator`

- generate internal candidates;
- gate for feasibility and quality;
- select up to three meaningfully different candidates;
- prove all share the same locked structure;
- use adaptive Quiet / Expressive / Bold anchors;
- return fewer than three if that is the honest result.

### `TreatmentAdmission`

Validate:

- structure lock;
- plan/schema consistency;
- effect registry metadata;
- source identities;
- capability availability;
- backend requirements;
- privacy/cost approval;
- safety gates;
- preview/export parity or disclosed limitation.

## Source ingestion

Do not bulk copy tutorials. For each starter card:

1. identify the exact claim needed;
2. retrieve the most authoritative source(s);
3. write an original short synthesis;
4. cite source ID, URL, version/date where available, and claim;
5. record uncertainty and conflicts;
6. add implementation and visual-validation evidence separately.

Technical Final Cut semantics require repository evidence or direct capture;
tutorial prose cannot create a semantic admission.

## Starter card set

Begin with a compact set that supports real current work:

- quiet still push/pan;
- focal-target push/rotate;
- opacity fade;
- short natural dissolve with handles;
- eye-trace/focal-position bridge analysis;
- restrained saturation/exposure adjustment with honest preview label;
- simple analog/CRT layer recipe once its production emitter exists;
- ease-in/ease-out as conceptual guidance, marked non-executable until encoding
  is proven;
- alpha/premultiplication quality check;
- mask/tracking edge-quality check;
- dialogue intelligibility and loudness check;
- typography readability check;
- caption requirement;
- flash/PSE safety rule;
- representative-media visual bakeoff procedure.

Then add cards alongside each new effect instead of attempting to encode the
entire history of editing at once.

## “Surprise Me” v1 scope

Ship the user-facing control only for a context where the current capability set
can produce at least two—and preferably three—genuinely distinct, admitted,
previewable treatments without changing structure.

A sensible first fixture is one still image with a confirmed focal target after
parameter truth is complete. Three variants can differ materially in motion
path, intensity, fade/color behavior, and representation, but must not be tiny
numeric perturbations.

For transition-only contexts where only Natural Dissolve is admitted, return one
excellent option or keep the control unavailable with an honest reason. Do not
invent three names for the same dissolve.

## UI

- Keep normal command-based planning.
- Add “Surprise Me” as an optional action, never the default replacement.
- State that clips and timing remain locked.
- Show equalized A/B/C previews plus original.
- Present plain-language treatment summaries.
- Support “Use this,” “Refine,” “Compare,” and reset.
- Expose technical provenance in an advanced panel.
- Invalidate stale export/package state after a treatment revision.

## Verification

Required test layers:

- schema/catalog tests;
- structure-lock property and mutation tests;
- option-diversity tests;
- capability/refusal tests;
- preview/export equality tests;
- deterministic replay tests;
- safety/accessibility tests;
- representative visual bakeoffs;
- manual app workflow screenshots and exported FCPXML/render inspection.

For subjective ranking, do not rely only on the generator's own score. Use
shuffled comparisons, record observations, and preserve all candidates and
parameters for review.

## Non-goals for the first integration milestone

- selecting or reordering clips;
- automatic trimming or retiming;
- rewriting narration;
- downloading or embedding all source materials;
- claiming a trained personal taste model;
- shipping unsupported generative backends;
- replacing the current plan/admission safety architecture wholesale;
- making “Surprise Me” available everywhere before effect breadth exists.

