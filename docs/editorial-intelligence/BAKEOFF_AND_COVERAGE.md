# Surprise Me — representative bakeoff and coverage

Recorded 2026-08-08 against the installed FrameSmith app and Final Cut Pro
**12.3 (450152)**.

## Coverage contract

| Scenario | Admitted choices | Honest boundary |
| --- | --- | --- |
| One admitted still, confirmed focal target | up to 3 | opacity, affine focal/quiet motion, and native CRT base treatment |
| One admitted still, no target | 2 or 3 | no target-dependent construction is invented; retrieval may return fewer genuine matches |
| Two adjacent clips | 1 | canonical native dissolve only; no padded alternatives |
| Missing capability or drifted evidence | 0 | state is cleared and the refusal is shown |

Determinism is pinned by canonical input, catalog, registry, capability, schema,
and seed identities. Diversity requires real construction differences on at
least two treatment dimensions; names or seed-only variation do not count.

## Five-class visual bakeoff

All five stills were loaded into the installed app, options were generated, all
available choices were added to Compare, and source plus admitted options were
viewed on the shared time control.

| Class | Source | Observed result |
| --- | --- | --- |
| Portrait + hair detail | `01_close_portrait_hair_detail.jpg` | historic up-to-three-option comparison; no masking claim, no obvious halo/warp in native treatments |
| Painting | `Marc_mushroom_queen_…png` | two genuine choices for the wording; source composition remained intact |
| Landscape with depth | `landscape-sonoma.png` | historic up-to-three-choice comparison; quiet push is a uniform affine move, not synthetic parallax |
| Architecture/grid | `architecture-grid.png` | straight lines remained straight; no distortion or masking route was used |
| Difficult fine edges | `organic-strands.png` | thin strands remained continuous; no edge-aware treatment claim was made |

Evidence screenshots:

- `/Users/marcboyer/Movies/FCPCommandConsole/verification/editorial-intelligence-20260808/31-comparison.png`
- `/Users/marcboyer/Movies/FCPCommandConsole/verification/editorial-intelligence-20260808/bakeoff-painting.png`
- `/Users/marcboyer/Movies/FCPCommandConsole/verification/editorial-intelligence-20260808/bakeoff-landscape.png`
- `/Users/marcboyer/Movies/FCPCommandConsole/verification/editorial-intelligence-20260808/bakeoff-architecture.png`
- `/Users/marcboyer/Movies/FCPCommandConsole/verification/editorial-intelligence-20260808/bakeoff-difficult-edges.png`

The Apple Vision analysis harness independently recorded:

| Image | Subject result | Boundary complexity |
| --- | --- | --- |
| portrait | single, 66.9% of frame | 0.017 |
| painting | four subjects | 0.056 |
| landscape | no person/animal subject mask | depth route only |
| architecture | no person/animal subject mask | depth route only |
| organic strands | single, 26.9% of frame | 0.034 |

Artifacts are under
`/Users/marcboyer/Movies/FCPCommandConsole/verification/editorial-intelligence-20260808/vision-analysis`.
This analysis describes source complexity; it does not turn the shipped affine
treatment into a depth or masking effect.

## What was visually judged

- Opacity fade uses neutral transform and a final 0.5-second 1.0→0.35 native
  opacity ramp. It introduced no crop, warp, or halo.
- Quiet push and drift keeps opacity at 1.0, moves scale 1.0→1.06, and applies a
  small `panX=0.015`, `panY=0`. Architecture and fine-edge stills showed no
  nonlinear deformation; edge crop remains the expected affine-move risk.
- Old television / CRT uses the base clip only in the demonstrated UI, a single
  1.0→0.82→1.0 opacity dip in the first second, and the admitted native color
  channel. There is no repeated flashing, generated static, scanline, or overlay
  claim. Color is indicative rather than calibrated.
- The shared loop moved source and all choices together. Each option displayed
  its distinct channel digest and "Shared admitted construction" disclosure.
- Changing explicit duration from 120 to 121 frames immediately cleared the
  option, comparison, and applied state with a visible structure-drift refusal.

The CRT recipe contains one bounded dip, well below the WCAG three-flashes-per-
second threshold used by the catalog's safety gate. That is a construction-level
safety result, not medical certification.

## Export parity

Three portrait choices produced distinct valid FCPXML packages:

| Choice | Package | FCPXML SHA-256 |
| --- | --- | --- |
| Quiet push | `7F786732-D610-474D-9784-92A03C836898` | `d5b55bbe62a7da27c73d9eb2f52ea57e22fb7dc265bce199592006bc23b5802f` |
| Opacity fade | `ED25D1F0-F7E4-4839-B240-9C4304262630` | `4d28058735c4b0335c63d446b49b88d1397cf7ebb34c0b6ef1fad7a010c73956` |
| CRT base | `F4846BF6-DD50-4A00-8F79-A6F273AD5039` | `49ce47706c76c331f99f98a0d131dbe7c55e002124fbd13cd49cb62f57195586` |

The post-fix painting opacity package
`3E43F9A8-4FFE-4698-8261-69AE79A2139D` has FCPXML SHA-256
`61276382d539bacc5a79322c2b63efe1bc6107210609ede3376b795edd0c5dbc`,
preserves source media SHA-256
`48a7c0eda7057e1c7075b996914eae24e0ed46d014a4315aee3db1fc3bfa25f4`,
and records the exact wording "Give this painting a quiet cinematic treatment
with a restrained finish." Its FCPXML imported and opened in the isolated copied
Final Cut app as a 4-second project with live native opacity animation.

## Bounded conclusion

The bakeoff supports construction correctness, truthful UI disclosures, source
preservation, obvious-artifact screening, and preview/export sharing for the
implemented native channels. It does **not** establish expert perceptual
preference, depth synthesis, edge-aware masking, calibrated color, audio
quality, or population safety.
