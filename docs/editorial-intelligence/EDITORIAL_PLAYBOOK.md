# Editorial Craft Playbook

This playbook distills recurring professional principles from the source atlas.
It is a decision aid, not a bag of mandatory formulas. The user's editorial
structure stays locked unless a request explicitly says otherwise.

## 1. The treatment hierarchy

Judge every effect decision in this order:

1. Does it serve the intended emotion?
2. Does it clarify or deepen the idea?
3. Does it fit the rhythm already created by the user's edit?
4. Does it guide the eye to the right place?
5. Does it preserve spatial and temporal coherence where coherence matters?
6. Is it technically clean, reproducible, and honestly previewed?

This adapts the spirit of Walter Murch's emotion/story/rhythm/eye-trace
hierarchy to FrameSmith's bounded role. FrameSmith does not choose a different
shot; it chooses how to treat the shot it has been given.

## 2. Restraint is a professional technique

An effect is justified when it adds meaning, directs attention, solves a visual
problem, or creates intentional texture. “Nothing extra” is a valid treatment.

Prefer the least conspicuous intervention that fully achieves the intent. Strong
effects should be motivated by content, movement, shape, light, sound, or an
explicitly requested style—not by a desire to prove the software is active.

Common signs of over-editing:

- every cut receives a transition;
- every still receives the same push-in;
- motion never settles;
- glow, grain, blur, chromatic aberration, or shake are stacked by default;
- a transition becomes the subject of the moment;
- typography moves faster than it can be read;
- sound effects announce every visual change;
- a reference style is copied literally instead of translated to the shot.

## 3. Eye guidance

Before adding motion or text, locate:

- the primary subject;
- faces and eyes;
- the likely current gaze position;
- important negative space;
- high-contrast distractors;
- protected edges and text-safe regions.

Motion should normally begin near the viewer's current attention and guide it
toward the intended focal point. Avoid sudden scale/position changes that make
the eye hunt. For a cut-adjacent treatment, compare the outgoing focal point and
incoming focal point; a visual bridge may use matching position, direction,
shape, luminance, color, or semantic association.

## 4. Motion craft

Professional motion has intention, acceleration, and rest.

- Use constant velocity only when mechanical neutrality is desired.
- Use ease-in/ease-out for natural starts and stops.
- Use asymmetric easing when entering and leaving have different emotional jobs.
- Use overshoot sparingly for playful, energetic, or physical motion.
- Preserve sub-pixel stability; accidental jitter reads as cheap.
- Add motion blur when the representation and shutter logic justify it.
- Let a move settle before an important title or visual detail must be read.
- Prefer one dominant motion idea per moment.

For stills, choose among:

- simple native pan/scale for quiet, reliable movement;
- layered parallax for clear foreground/background separation;
- continuous depth warp for richer spatial motion;
- localized atmospheric or generative motion for elements that should live;
- no motion when the still's stillness is itself the point.

Depth motion must respect occlusion. Edge tearing, rubber-sheet deformation,
haloing, and implausible relative motion fail the effect even if the depth map is
numerically plausible.

## 5. Transitions

The default transition is a cut. FrameSmith is not authorized to move that cut,
but it may construct a treatment around it.

Choose a transition family by its job:

| Job | Strong candidates | Typical failure |
| --- | --- | --- |
| Invisible continuity | cut, short dissolve, sound bridge | visible “preset” feel |
| Time/place softening | dissolve, fade, luma fade | muddy overlap or excessive length |
| Energy/motion bridge | whip, zoom, directional blur | directions do not match |
| Graphic association | shape/color/match transition | no real visual correspondence |
| Object-motivated reveal | foreground wipe, doorway/window mask | bad tracking or matte edges |
| Memory/dream shift | diffusion, light leak, film burn, temporal echo | cliché or illegibility |
| Conceptual transformation | displacement, melt, ink, generative bridge | artifacts become the focus |

Transition quality depends on both ends. Analyze handles, dominant motion,
subject placement, luminance, color, texture, and audio. Never move the user's
edit point merely to make a transition easier. If handles are insufficient,
refuse that construction or use a non-handle-dependent alternative.

## 6. Compositing

A believable composite matches:

- perspective and lens behavior;
- motion and tracking;
- edge softness and motion blur;
- exposure, contrast, white balance, and black level;
- grain/noise structure;
- depth, occlusion, and atmospheric falloff;
- focus and depth of field;
- light direction and spill.

Inspect mattes on black, white, and representative backgrounds. Watch for dark
or bright fringes caused by straight/premultiplied-alpha mismatches. Preserve
high-bit-depth intermediates when repeated transforms or grading would expose
banding.

## 7. Color

Separate correction from creative look:

1. identify input color space and transform correctly;
2. normalize exposure and white balance;
3. match adjacent shots when requested;
4. protect skin tones, artwork, and critical brand colors;
5. build contrast and palette for the intended feeling;
6. check scopes, gamut, clipping, banding, and SDR/HDR output behavior.

Do not map emotions to colors as a rigid dictionary. “Lonely” may be cold and
desaturated, but it may also be warm, empty, and low-contrast. Offer a rationale
and let the media decide.

Never claim that a local preview exactly matches Final Cut color unless the
mapping is calibrated and tested for the relevant color pipeline.

## 8. Texture and looks

Grain, halation, bloom, gate weave, vignette, scan lines, chromatic aberration,
dropout, and compression artifacts are not interchangeable “vintage” signals.
Each implies a physical or historical process.

Use texture in a scale-aware way:

- grain size should relate to output resolution and intended stock/medium;
- bloom should arise around highlights, not flatten the whole image;
- vignette should support focus without obvious black corners;
- CRT/analog effects should respect scan direction, phosphor/line structure,
  distortion, and signal behavior;
- degradation should preserve the important subject unless damage is the point.

## 9. Typography

Typography must communicate before it decorates.

- Establish hierarchy through size, weight, spacing, placement, and timing.
- Keep sufficient contrast against changing imagery.
- Respect title-safe/action-safe regions and captions.
- Use line length and line breaks that can be read at playback speed.
- Animate according to syntax or meaning when possible.
- Avoid motion that competes with the words.
- Allow entry, reading, and exit time.
- Test at the smallest expected screen size.

For Cosmic Tea Shop, the default aesthetic should be thoughtful and cinematic:
measured motion, strong negative space, restrained palette, and typography that
feels integrated with paintings and surreal imagery rather than pasted over it.

## 10. Sound treatment

Sound often sells a visual effect more effectively than more pixels.

Organize conceptually into dialogue/narration, music, ambience, Foley, and
effects. Preserve sync and the user's music structure.

Priorities:

1. intelligible, natural narration/dialogue;
2. smooth edit boundaries and room/ambience continuity;
3. appropriate dynamic range;
4. music that supports rather than masks speech;
5. effects that motivate or complete visual movement;
6. measured loudness and true peak for the intended delivery.

Use audio bridges, pre-laps, tails, and perspective shifts to make visual
transitions feel coherent. Do not add a whoosh to every move. Match spectral
weight, duration, and amplitude to the visual event.

## 11. Accessibility and safety

- Provide accurate, synchronized captions when requested or at delivery.
- Preserve important non-speech audio information in captions.
- Keep text readable in size, contrast, duration, and placement.
- Do not generate more than three flashes in any one-second period unless the
  flash is demonstrably below the applicable threshold; safer is to avoid
  rapid flashing entirely.
- Treat red flashes, high-contrast patterns, and large-area flicker cautiously.
- Do not place a warning after hazardous imagery has begun.
- Avoid unnecessary rapid zoom/parallax that may create vestibular discomfort.

## 12. Quality is comparative

For a new flagship effect, render several representative cases and compare:

- current baseline;
- proposed implementation;
- at least one plausible alternative;
- an intentionally strong parameter setting that exposes artifacts.

Use portraits, paintings, landscapes, architecture, difficult edges, low light,
and motion when relevant. Technical tests prove correctness; blinded or shuffled
A/B viewing helps judge whether the result actually looks better.

