# Effect Decision System

## Goal

Convert the user's locked media sequence and creative direction into one or more
high-quality treatments without taking authority over clips, order, timing, or
story structure.

## Inputs

- `EditorialStructureLock`
- admitted media identities and technical metadata
- neighboring frames/short preview samples
- user command and explicit constraints
- selected quality strategy: Auto, Fast, Editable, or Best
- current `CapabilityCatalog`
- relevant `TechniqueCard` records
- prior approved treatment, if revising
- optional taste profile built only from explicit choices/ratings

## Evidence extraction

Analyze only what is needed for treatment:

- media type, duration, frame rate, resolution, color metadata, audio layout;
- faces, subject masks, salient objects, text, horizon, vanishing lines;
- foreground/background separability and depth confidence;
- dominant motion and direction near edit boundaries;
- luminance, contrast, palette, texture, grain/noise;
- available negative space and protected regions;
- source handles without changing the locked edit point;
- audio transients, tempo, speech activity, and ambience continuity;
- likely failure risks: hair, transparency, fast motion, occlusion, clipped
  highlights, mixed color spaces, or insufficient handles.

Do not turn treatment analysis into an excuse to select different footage.

## Intent model

Represent the request as separable goals:

- emotional intent;
- semantic focal point;
- motion intent;
- transition intent;
- look/color intent;
- texture/medium intent;
- typography intent;
- sound-treatment intent;
- preservation constraints;
- prohibited changes;
- intensity;
- quality/speed/editability preference;
- ambiguities and confidence.

Keep the original words. Interpretations are hypotheses, not replacements.

## Candidate generation

Retrieve technique cards by:

1. effect domain;
2. emotional/semantic intent;
3. media prerequisites;
4. current capability support;
5. quality strategy;
6. failure-risk compatibility.

Construct candidates from compatible techniques. Every candidate must declare:

- what it changes;
- what it preserves;
- required handles/assets/models;
- backend/representation;
- adjustable parameters;
- expected latency/cost;
- editability layer;
- known risks;
- preview fidelity;
- provenance source IDs.

## Feasibility gate

A candidate is executable only if:

- the current app/export path can realize it;
- required media evidence is present;
- required handles exist or are unnecessary;
- required models/dependencies are available;
- any external cost/upload approval has been obtained;
- preview and export share the same construction or disclose the precise gap;
- the editorial-structure fingerprint remains unchanged;
- relevant safety and accessibility gates pass.

Never surface an attractive but nonfunctional treatment as though it were ready.
Unsupported ideas may appear separately as “not available yet,” not among the
up-to-three primary Surprise Me options.

## Ranking

Rank candidates with a transparent multi-factor score. Do not pretend subjective
quality can be reduced to a universal scalar, but use consistent factors:

- intent fidelity;
- estimated visual quality;
- technical fit to the actual media;
- restraint/motivation;
- artifact risk;
- preview/export fidelity;
- reliability;
- revision quality;
- render latency;
- monetary cost;
- requested editability strategy;
- redundancy with other candidates.

The highest raw score does not automatically produce three options. Use
semantic-dimension diversity selection after quality gating; return fewer when
the available constructions do not make honest alternatives.

## Revision

A revision should patch semantic treatment goals or parameters, then revalidate
the full construction. “Less magical, keep the depth” should reduce glow,
particles, distortion, or fantastical transition behavior without destroying
the approved depth/parallax work.

Preserve the last valid treatment if a revision fails. Mint a safe new operation
identity for revised exports according to the repository's non-overwrite policy.

## Honest fallback

When the ideal treatment cannot be executed:

1. preserve editorial structure;
2. state the limiting evidence/capability;
3. choose the strongest admitted fallback;
4. explain the visual compromise in one sentence;
5. never fake support with a disconnected preview.
