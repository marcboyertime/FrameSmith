# Source Atlas

The machine-readable catalog contains **153 unique sources across 54 category
labels**. It mixes official technical documentation, professional training,
standards, research papers, practitioner analysis, and visual-reference
collections.

The catalog is intentionally broader than FrameSmith's current runtime. It is a
development and retrieval map. A source does not become a production capability
until a construction exists, preview/export share it, and representative visual
tests pass.

## Source hierarchy

Use sources according to their role:

1. **Captured evidence from the actual Final Cut version** — strongest authority
   for undocumented FCPXML semantics.
2. **Official product documentation and standards** — technical behavior,
   formats, safety, accessibility, and delivery.
3. **Official professional training** — workflow and craft exercises.
4. **Respected practitioners and institutions** — taste, judgment, examples,
   failure modes, and creative language.
5. **Peer-reviewed research** — candidate architectures, datasets, and evals.
6. **Inspiration collections** — visual vocabulary only; never technical proof.

When a tutorial conflicts with direct behavior in Final Cut Pro 12.3 build
450152, preserve the conflict and trust the version-scoped capture.

## A. Minimum editorial-craft foundation

Start here when an agent needs to reason about why a treatment should exist:

- `MURCH-001` through `MURCH-003` — emotion, story, rhythm, eye trace, space.
- `EFAP-001` through `EFAP-004` — visual explanation, movement, comedy, sound.
- `FILM-TEXT-001` — open continuity/montage foundation.
- `INSIDEEDIT-001` — pacing as variable emotional design.
- `INSIDEEDIT-002` — B-roll action flow and emotional alignment.
- `ADOBE-EDIT-001` through `ADOBE-EDIT-005` — cut and transition vocabulary.
- `POND5-001` — match cuts including metaphorical association.

FrameSmith should learn these principles so it can treat the user's chosen clips
intelligently. It must not use them to seize control of clip selection or order.

## B. Final Cut and Motion implementation core

For any production claim, start with:

- `APPLE-FCP-001` — current user-guide entry.
- `APPLE-FCP-002` — Magnetic Timeline and spine model.
- `APPLE-FCP-008` through `APPLE-FCP-019` — keyframes, transitions, tracking,
  and masks.
- `APPLE-FCP-020` through `APPLE-FCP-030` — color, alpha, and audio.
- `APPLE-FCP-031` through `APPLE-FCP-039` — captions and delivery.
- `APPLE-DEV-001` through `APPLE-DEV-006` — supported integration and FCPXML.
- `APPLE-MOTION-001` through `APPLE-MOTION-006` — templates, timing, behaviors,
  masks, and 3D depth of field.
- `APPLE-CODEC-001` and `APPLE-CODEC-002` — ProRes and ProRes RAW.

The official manuals establish supported concepts; repository capture evidence
must still establish uncodified numeric semantics and version-specific FCPXML.

## C. Professional end-to-end curriculum

Blackmagic's official, free project-based books are unusually valuable because
they span the whole post pipeline:

- `BLACKMAGIC-002` — editor curriculum.
- `BLACKMAGIC-003` — colorist curriculum.
- `BLACKMAGIC-004` — Fairlight audio post.
- `BLACKMAGIC-005` and `BLACKMAGIC-006` — compositing and advanced VFX.
- `BLACKMAGIC-007` — broad workflow foundation.

The software differs from Final Cut, but the craft, diagnostics, and quality bar
transfer well. Translate principles into FrameSmith constructions; do not copy
UI steps literally.

## D. Motion, typography, and title design

For animation quality:

- `ADOBE-AE-001`, `ADOBE-AE-003`, and `ADOBE-AE-004` — keyframes, graph editor,
  motion blur, and official exercises.
- `VMG-001`, `SOM-001`, `SOM-002`, and `JAKEMOTION-001` — motion principles and
  practitioner vocabulary.
- `APPLE-MOTION-002` through `APPLE-MOTION-005` — how those ideas become
  reusable Final Cut templates.

For typography and title sequences:

- `ADOBE-DESIGN-001` and `RMCAD-001` — hierarchy and readability.
- `ARTTITLE-001` — large curated reference archive.
- `ART-TITLE-VIDEO-001` — title design as narrative metaphor.
- `SAULBASS-001`, `IDEO-001`, and `IOWA-THESIS-001` — history and conceptual
  economy.

Do not imitate a title sequence wholesale. Extract the design logic: hierarchy,
negative space, metaphor, timing, relationship to sound, and service to the work.

## E. Compositing, masks, and object-aware work

Core references:

- `ADOBE-AE-002` — alpha, masks, and mattes.
- `CIECHANOWSKI-001` — alpha and premultiplication made visually clear.
- `W3C-COMP-001` — formal blend/compositing model.
- `FOUNDRY-001` and `FOUNDRY-002` — professional Nuke workflow and keying.
- `BLACKMAGIC-005` and `BLACKMAGIC-006` — node-based tracking, keying, cleanup,
  particles, and 3D.
- `APPLE-FCP-015` through `APPLE-FCP-019` — native tracking and masks.

Technique cards derived here should include edge, blur, grain, color, light,
focus, occlusion, and tracking checks—not only “mask exists.”

## F. Living Still and paintings

This is central to Cosmic Tea Shop:

- `NIKLAUS-001` and `NIKLAUS-002` — 3D Ken Burns depth/view-synthesis method.
- `PARALLAX-001` — classic separated-layer workflow.
- `PARALLAX-002` — depth-map/displacement workflow in Fusion.
- `PARALLAX-003` — an AI-depth Final Cut/Motion product reference.
- `APPLE-MOTION-006` — depth-of-field behavior.

Agents should compare simple pan/scale, separated planes, continuous depth warp,
hybrid segmentation/depth, and localized generative motion. The default should
be selected by visual evidence, not editability ideology.

## G. Color and texture

Technical backbone:

- `APPLE-FCP-020` through `APPLE-FCP-028` — Final Cut color and HDR behavior.
- `BLACKMAGIC-003` — colorist exercises and scopes.
- `ACES-001`, `ACES-002`, and `FRAMEIO-004` — ACES and color management.
- `FRAMEIO-003` and `FRAMEIO-005` — practitioner explanations.
- `APPLE-CODEC-001` and `APPLE-CODEC-002` — codec and bit-depth context.

Convert broad requests such as “colder and lonelier” into testable treatment
hypotheses, not a rigid emotion-to-slider dictionary. Preserve technical color
management before applying a look.

## H. Sound design and mix

Start with:

- `BLACKMAGIC-004` — structured official audio curriculum.
- `SOUND-001` through `SOUND-005` — full mix, dialogue, Foley, music, and repair.
- `IZOTOPE-001` — restoration/mixing tutorials.
- `APPLE-FCP-010` and `APPLE-FCP-030` — Final Cut automation and enhancement.
- `EBU-001` and `ITU-001` — loudness and true-peak standards.
- `FRAMEIO-001` — dialogue-edit and post-workflow context.

Loudness-match A/B previews. A louder option often appears falsely “better.”

## I. YouTube feedback and delivery

- `YOUTUBE-001` and `YOUTUBE-002` — official retention and key-moment analysis.
- `YOUTUBE-003` — official upload encoding.
- `YOUTUBE-004` and `YOUTUBE-005` — current creator and policy resources.
- `YOUTUBE-006` through `YOUTUBE-008` — documentary B-roll and sound examples.

Retention should be feedback, not a command to make every moment faster. Use the
user's analytics to locate treatment problems; preserve the director's intended
quiet and variation.

## J. Accessibility, safety, and copyright

Required gates:

- `W3C-A11Y-001` through `W3C-A11Y-003` — captions and audio description.
- `W3C-SAFETY-001`, `OFCOM-001`, and `HARDING-001` — flashing/PSE safety.
- `SECTION508-001` and `SECTION508-002` — practical synchronized-media guidance.
- `COPYRIGHT-001`, `COPYRIGHT-002`, `YOUTUBE-LAW-001`, and
  `VIDEOGRAPHIC-001` — fair-use context for video essays.

There is no universal “safe number of seconds” for copyrighted media. Keep legal
analysis separate from aesthetic treatment and surface uncertainty.

## K. Research for recommendation and evaluation

Particularly relevant to a future bounded “Surprise Me” system:

- `RESEARCH-TRANS-001` — multimodal transition recommendation.
- `RESEARCH-CUTS-001` and `RESEARCH-AVE-001` — editing/cinematography labels.
- `RESEARCH-QUALITY-001` — holistic audio-video evaluation dimensions.
- `RESEARCH-SHOTDIRECTOR-001` — controllable transition prompting.
- `RESEARCH-CONTINUITY-001` — formal continuity constraints.

`RESEARCH-ROUGH-001` and `RESEARCH-SOCIAL-001` contain useful ways to encode
editing idioms and constraints, but are marked `boundary_only`: their automatic
clip-selection goals conflict with FrameSmith's default authority boundary. Use
their representation ideas, not their editorial autonomy.

## Retrieval recipes

### “Make this painting slowly come alive”

Retrieve:

- director-control contract;
- `NIKLAUS-001`, `PARALLAX-001`, `PARALLAX-002`;
- `APPLE-MOTION-002`, `APPLE-MOTION-004`, `APPLE-MOTION-006`;
- motion-quality and compositing cards;
- Living Still representative-media rubric.

### “Give me three transition options here”

Retrieve:

- director-control contract and Surprise Me design;
- `APPLE-FCP-011` through `APPLE-FCP-014`;
- `ADOBE-EDIT-002`, `ADOBE-EDIT-003`, `POND5-001`;
- `RESEARCH-TRANS-001`;
- handle, motion-direction, focal-point, and audio-bridge cards.

### “Make this feel like a memory I barely trust”

Retrieve:

- color/texture, motion, and sound cards;
- `MURCH-001`, `EFAP-001`, `BLACKMAGIC-003`, `BLACKMAGIC-004`;
- Final Cut color/audio implementation references;
- avoid a single canned “memory” preset; generate multiple hypotheses.

### “Put the quote behind the person”

Retrieve:

- tracking/mask/alpha cards;
- `APPLE-FCP-015` through `APPLE-FCP-019`;
- `ADOBE-AE-002`, `CIECHANOWSKI-001`;
- typography and title-timing cards;
- mobile readability and matte-edge gates.

## Refresh policy

Record `last_checked` when converting a source into a technique card. Recheck
product manuals, standards, APIs, model repositories, pricing, and platform
guidance before using them for current claims. Timeless craft analysis needs less
frequent refresh but may still contain dead links or rights restrictions.

