# “Surprise Me” — Bounded Three-Treatment Design

## Product promise

The user supplies the clips and their order. “Surprise Me” answers:

> Given this exact editorial structure, what are three excellent ways to treat
> this moment?

It does not answer:

> What story should I make from this footage?

## Invariants

All three options must share an identical `EditorialStructureLock`:

- same media identities;
- same clip order;
- same edit points;
- same visible durations and retiming;
- same audio sync;
- same narration and music structure;
- same protected/approved elements.

The UI should say explicitly: “Your clips and timing are locked. These options
change only the treatment.”

## Option generation

### Step 1 — define a quality floor

Generate more internal candidates than the user will see. Eliminate candidates
that are unsupported, generic, artifact-prone, structurally invasive, unsafe, or
too similar to one another.

### Step 2 — establish adaptive anchors

Use three default anchors, adapted to the moment:

1. **Quiet / Cinematic**
   - minimal intervention;
   - motivated motion;
   - subtle color and sound polish;
   - high reliability;
   - the effect does not call attention to itself.

2. **Expressive / Thematic**
   - clearer mood or metaphor;
   - more pronounced spatial, color, texture, typographic, or sound design;
   - still restrained enough for the content.

3. **Bold / Experimental**
   - the strongest coherent concept supported by the media and capability set;
   - may use rendered, depth-aware, ML-assisted, or generative construction;
   - must remain professional, revisable, and honest about artifacts/cost.

For a naturally quiet or sacred moment, even the “Bold” option may be subtle.
For a chaotic or comic moment, all three may be energetic. Diversity should be
relative to the content, not a fixed intensity slider.

### Step 3 — enforce meaningful difference

At least two treatment dimensions must differ materially across each pair:

- motion language;
- transition mechanism;
- palette/contrast strategy;
- texture/medium;
- spatial/depth strategy;
- typography behavior;
- sound-treatment strategy;
- backend/representation.

Changing only a random seed, tiny numeric value, or LUT is not a distinct option.

### Step 4 — preserve common quality

Every option must pass the same technical and visual gates. “Experimental” does
not mean broken edges, unreadable text, arbitrary shake, or generative drift.

## Option card

Each option should display:

- name;
- one-sentence creative idea;
- three to six plain-language changes;
- explicit preserved structure statement;
- expected render time and any cost/upload disclosure;
- editability level: Final Cut, FrameSmith regeneration, source composition;
- approximate/unverified badges where needed;
- relevant controls;
- preview button;
- “Use this,” “Refine,” and “Compare” actions.

Do not lead with backend names. Technical details belong in an expandable panel.

## Preview protocol

- Use identical source interval and playback conditions for all options.
- Loudness-match audio previews.
- Do not give one option more screen time or a more flattering poster frame.
- Allow A/B/C looping and a source/baseline comparison.
- Keep option labels hidden or shuffled during an optional blind comparison.
- Derive preview from the same treatment construction used by export.

## Revision examples

- “Option 2, but use the quieter motion from 1.”
- “Keep the transition; remove the grain.”
- “Half the depth, keep the light shimmer.”
- “Make the bold one less magical and more physical.”
- “Same treatment, but protect the face completely.”

The system should patch composable semantic dimensions, not restart from an
opaque text prompt.

## Memory and taste

Taste learning may use explicit selections, rejections, ratings, and revisions.
It must not silently override the request. Record tendencies such as:

- prefers restrained over flashy;
- likes slow depth movement on paintings;
- often removes excessive bloom;
- prefers integrated serif typography;

Use these as ranking priors, and keep the three options diverse enough to avoid
trapping the user in a feedback loop.

## Failure behavior

If fewer than three genuinely distinct executable treatments exist:

- show the strongest available options;
- state why the set is smaller;
- do not pad the UI with fake variants;
- identify the missing capability that would unlock a stronger third option.

