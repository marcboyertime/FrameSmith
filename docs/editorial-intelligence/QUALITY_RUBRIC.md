# FrameSmith Treatment Quality Rubric

Use this rubric for design review, automated checks where possible, and visual
bakeoffs. A high average cannot excuse a blocker.

## Blockers

Reject the treatment if any are true:

- editorial structure changed without explicit authority;
- source media or sync was silently altered;
- preview and export use materially different constructions without disclosure;
- a visible control does nothing;
- the result contains severe warping, matte, flicker, banding, alpha, or tracking
  artifacts;
- essential text is unreadable;
- color-space handling is unknown in a way likely to corrupt the output;
- audio clips, distorts, pumps, or masks speech unintentionally;
- flashes violate the applicable safety threshold;
- an external upload or paid call occurs without the established approval flow;
- the implementation claims native/editable/accurate behavior not supported by
  evidence.

## Scoring

Score each dimension 1–5. Record evidence, not only a number.

### 1. Intent fidelity

1: contradicts the request.  
3: literal but generic.  
5: captures the requested feeling and its nuance.

### 2. Visual quality

1: obvious preset/artifact.  
3: competent and clean.  
5: polished, coherent, and presentation-ready.

### 3. Motivation and restraint

1: arbitrary decoration.  
3: mostly justified.  
5: every strong choice has a clear visual, semantic, or rhythmic reason.

### 4. Eye guidance and composition

1: distracts or loses the subject.  
3: preserves focus.  
5: deliberately guides attention and uses the frame beautifully.

### 5. Motion quality

1: jittery, robotic, or implausible.  
3: smooth and serviceable.  
5: expressive timing, convincing acceleration, spatial coherence, and rest.

### 6. Compositing integrity

1: broken masks/edges/lighting.  
3: clean at normal viewing.  
5: holds up on edge, motion, grain, color, focus, and occlusion inspection.

### 7. Color and texture

1: clipped, inconsistent, or indiscriminate.  
3: technically sound and appropriate.  
5: controlled palette/contrast with texture that feels physically and
emotionally integrated.

### 8. Typography

Use N/A when absent.

1: unreadable or disconnected.  
3: clear and well placed.  
5: hierarchy, timing, type choice, and motion reinforce meaning.

### 9. Sound treatment

Use N/A when absent.

1: distracting, clipped, or speech-masking.  
3: clean and balanced.  
5: natural continuity, intentional dynamics, and sound that completes the image.

### 10. Revision quality

1: opaque/restart-only.  
3: core parameters can be changed.  
5: semantic components can be refined independently with deterministic history.

### 11. Reliability and performance

1: fragile or impractical.  
3: repeatable within stated constraints.  
5: robust, cancellable, cached where appropriate, and honest about latency.

### 12. Provenance and honesty

1: untraceable or overclaimed.  
3: implementation and limitations documented.  
5: source-backed technique choices, reproducible plan, truthful fidelity labels,
and clear capability evidence.

## Comparative acceptance

A new flagship implementation should not replace an existing one merely because
it is newer. Accept it as the default only when:

- it has no blockers;
- it wins or meaningfully expands coverage on representative media;
- its artifact envelope is understood;
- its fallback behavior is defined;
- preview/export parity is tested;
- the user can revise or revert it;
- the quality gain justifies cost, latency, and complexity.

## Representative media matrix

Where relevant, test:

- portrait with fine hair and glasses;
- painting or textured artwork;
- landscape with clear depth planes;
- architecture with straight lines;
- low-light/noisy footage;
- high-contrast highlights;
- transparent/translucent objects;
- fast motion and motion blur;
- mixed aspect ratios;
- mixed SDR/HDR or log/display-referred sources;
- narration over music;
- tiny mobile-screen typography.

## Review record

For each bakeoff, store:

- source-media hash and nonprivate fixture label;
- compared implementation/version IDs;
- exact parameters and seeds;
- render environment;
- representative frames and short preview paths;
- scores and written observations;
- known failures;
- chosen default/fallback decision and rationale.

