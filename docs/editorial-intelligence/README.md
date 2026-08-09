# FrameSmith Editorial Intelligence Pack v1

Created: 2026-08-06  
Target project: `marcboyertime/FrameSmith`  
Primary branch at research time: `standalone-app`  
Observed repository checkpoint: `7c8aed7a9ccfc2d080edbe95d95b59b59dbba98e`

## Purpose

This package gives FrameSmith's coding agents a curated, source-linked body of
professional post-production knowledge and a concrete architecture for turning
that knowledge into better effects, previews, recommendations, and quality
checks.

It is deliberately **not** an automatic story editor. The user remains the
director and picture editor: the user chooses the clips, their order, and their
place in the sequence. FrameSmith is the elite craftsperson that performs the
requested motion, compositing, transitions, typography, color, sound treatment,
and finishing.

## Non-negotiable product rule

FrameSmith must never silently:

- replace, omit, duplicate, reorder, or trim user-selected clips;
- alter an edit point, clip duration, speed, or audio sync;
- substitute different source media;
- rewrite narration or choose the story structure.

Those actions require a separate, explicit user request. See
`knowledge/DIRECTOR_CONTROL_CONTRACT.md`.

## What “Surprise Me” means

“Surprise Me” is a bounded treatment generator. It preserves the user's selected
media, ordering, edit points, durations, sync, and protected regions, then
creates up to three meaningfully different treatment options. It may return
fewer when semantic diversity cannot be established honestly. Each option must be:

- executable with the current admitted capabilities;
- previewable before export;
- described in plain language;
- traceable to editable parameters and source-backed technique cards;
- different in creative treatment, not merely a random seed;
- individually revisable without disturbing the locked editorial structure.

The default up-to-three-option spread is:

1. **Quiet / Cinematic** — restrained, motivated, nearly invisible craft.
2. **Expressive / Thematic** — stronger visual metaphor and atmosphere.
3. **Bold / Experimental** — the most adventurous option that remains coherent
   and technically honest.

These are diversity anchors, not fixed style presets. They should adapt to the
actual media and direction.

## Package map

- `knowledge/DIRECTOR_CONTROL_CONTRACT.md` — authority boundaries and invariants.
- `knowledge/EDITORIAL_PLAYBOOK.md` — distilled professional craft principles.
- `knowledge/EFFECT_DECISION_SYSTEM.md` — how to turn intent and media evidence
  into treatments without taking over the edit.
- `knowledge/SURPRISE_ME_DESIGN.md` — up-to-three-option generation, semantic diversity, safety,
  and UX rules.
- `knowledge/QUALITY_RUBRIC.md` — visual, sonic, technical, and honesty gates.
- `knowledge/TECHNIQUE_CARD_SCHEMA.md` — machine-usable knowledge-card format.
- `sources/SOURCE_ATLAS.md` — guided curriculum and source hierarchy.
- `sources/sources.csv` — machine-readable catalog of curated sources.
- `integration/CODEX_INTEGRATION_SPEC.md` — recommended repository integration.
- `integration/NEXT_CODEX_PROMPT.md` — detailed prompt to give the next agent.
- `manifest.json` — package metadata and file roles.

## How Codex should use this pack

1. Read the director-control contract first.
2. Inspect the real repository and its current `AGENTS.md` before acting.
3. Treat source entries as a retrieval map, not as automatically true rules.
4. Prefer primary and official sources for technical behavior.
5. Use practitioner sources for taste, examples, and failure modes.
6. Convert relevant material into small provenance-bearing technique cards.
7. Retrieve only the cards relevant to the current effect or quality review.
8. Test visual claims with representative media and side-by-side comparisons.
9. Never claim that a treatment is supported until it is executable through the
   same construction used by preview and export.

OpenAI's Codex guidance recommends durable repository context, clear constraints,
explicit completion criteria, and continuous validation. This pack follows that
pattern: the long-lived doctrine belongs in repository guidance, while detailed
knowledge stays in referenced files that are loaded only when relevant.

## Copyright and source-use policy

This archive contains links, short original annotations, and synthesized
principles. It does not redistribute paid courses, books, films, or copied
tutorial text. Agents should retrieve public sources as needed, obey access and
license terms, avoid long quotations, and record source provenance for any
derived technique card.

## Recommended sequencing

The current verified architectural prerequisite is truthful end-to-end parameter
control: enabled controls must change the validated plan, shared preview
construction, and export. Do not put a broad recommendation system on top of
controls or emitters that do nothing.

Once that prerequisite is complete, integrate this pack as the foundation for:

1. provenance-bearing technique cards;
2. treatment planning under locked editorial structure;
3. up-to-three-option “Surprise Me” generation;
4. effect-by-effect visual bakeoffs and capability expansion;
5. feedback/history that learns the user's taste without taking away control.
