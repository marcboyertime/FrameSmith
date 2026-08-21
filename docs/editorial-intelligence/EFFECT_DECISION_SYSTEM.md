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

## Current rendered-effect decisions

Two quality decisions use the shared rendered-movie construction. Old
Television v2 and Living Still v2 are both admitted and validated:

| Effect | Selected construction | Why | Honest editability |
| --- | --- | --- | --- |
| Living Still v2 | one continuous Core ML depth inference reused across a content-addressed video-only ProRes 422 HQ movie; selected defaults are 0.90 depth motion and 0.030 push | avoids the binary seam and hair-fringe ceiling observed in the Vision two-plane candidate; the selected recipe was the strongest artifact-free candidate and passed all ten final HQ checks | regenerate from the retained FrameSmith recipe; not a native transform and not a fade |
| Old Television v2 | sustained typed CRT render with scanlines, temporal noise, tube geometry/overscan, chroma shift, ghosting, bloom, jitter/tracking, vignette, and at-most-two-percent micro-flicker | the earlier native dip/color recipe did not deliver a continuous CRT treatment | regenerate from the retained FrameSmith recipe; not a native base recipe and not a fade |

Both preview and export consume one checksum-bound prepared movie. A missing
model/tool, changed source or recipe identity, hash drift, failed video-only
ProRes verification, or revoked Final Cut semantic contract refuses the option;
none of those conditions authorize a native or fade approximation.

Project export is additionally bounded to Final Cut 12.3 (450152), FCPXML 1.14,
1920×1080, 30 fps, 120 frames, four seconds, ProRes 422 HQ (`apch`,
`yuv422p10le`), and video-only. Arbitrary duration/aspect renders remain
preview-only and are refused for project export.

The evidence is deliberately split. The 10-case, 20-movie production bakeoff
establishes representative visual behavior for each effect. The still- and
movie-parent Final Cut 12.3 returned artifacts establish the connected rendered-
movie layer construction. Neither evidence class substitutes for the other.

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
3. choose the strongest admitted fallback only when it is the same requested
   creative job rather than a superficially convenient fade or native move;
4. explain the visual compromise in one sentence;
5. never fake support with a disconnected preview.
