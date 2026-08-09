# Editorial Intelligence Foundation — implementation status

Recorded 2026-08-08 for Final Cut Pro **12.3 (450152)**.

## Delivery boundary

The implementation baseline was `e174a5f` (`Record installed parameter acceptance`).
The foundation is delivered by the local editorial-intelligence commit series:
strict catalog and structure admission, installed-app Surprise Me workflow,
registry/emitter parameter truth, wording provenance, and subsequent
determinism, provenance, and timing hardening. Use the current local `git log`
for the exact commit chain rather than treating this status document as a
release ledger.

No remote push is part of this milestone.

## Runtime architecture

The production path is deliberately linear and fail-closed:

1. `EditorialKnowledgeCatalog` decodes the strict 15-card catalog and verifies
   card identities, provenance, status, risk, and required construction.
2. `EditorialStructureLock` captures ordered clip identities, exact rational
   durations, edit points, and audio-sync constraints. Treatments carry its
   SHA-256 fingerprint and cannot authorize clip, order, timing, or sync
   changes.
3. `TreatmentOptionGenerator` retrieves only context-appropriate cards,
   constructs at most three deterministic and materially distinct plans, and
   explains a shortfall instead of padding the set.
4. `TreatmentAdmissionService` rechecks structure, capability, registry,
   catalog, schema, media, channel, and emitted-duration snapshots immediately
   before use. Only admitted options reach execution.
5. `EditorialTreatmentWorkflow` owns Surprise Me, Preview, Use This, Refine,
   Compare, history, restore, structure-drift invalidation, and exact-plan
   adoption without reparsing the director's wording.
6. `StandaloneEmitterCatalog` is the shared construction boundary used by
   preview and export. Export re-admits and confirms that its emitted channel
   construction still matches the admitted construction.

Operation IDs are minted only when a user selects an option. Stable catalog,
structure, and channel identities use canonical SHA-256 encodings rather than
Swift's process-randomized `Hashable` values.

## Parameter truth

Registry presentation metadata remains the source of truth for editability.
The plan carries values, the validator checks them against the current
registry, and the emitter produces the native channels sampled by the viewer
and written to FCPXML.

- Living Still is runtime-editable for duration, start/end scale, pan X/Y,
  start/end opacity, and fade duration. Pan X is a width fraction converted to
  Final Cut height units; pan Y is sign-inverted for Final Cut's positive-up
  axis. Stills use the 3600-second origin, movies use zero, durations are
  frame-quantized, and the final keyframe remains addressable.
- Targeted Rotate + Zoom is runtime-editable for duration, scale, and signed
  rotation. Positive Final Cut rotation is counterclockwise. A confirmed focal
  point is typed execution input, not an invented parameter.
- Natural Dissolve has a production emitter, but its canonical 12-frame
  duration and other construction values remain unsupported/read-only in the
  generic parameter editor. The emitter refuses insufficient handles rather
  than moving an edit point.
- Old Television has a native base emitter and an optional admitted-still
  overlay descriptor. Its nine canonical values are unsupported/read-only or
  invariant/read-only; no arbitrary color mapping, generated grain, scanline,
  or FFmpeg asset is claimed.
- Missing or unverified liveness metadata is read-only. Easing and Living Still
  color enrichment remain unsupported because their user-editable production
  mappings have not been established.

## Starter catalog

Every card has strict schema validation and at least one provenance reference.
Only `validated` cards can be retrieved for automatic construction.

| Card ID | Status | Production boundary |
| --- | --- | --- |
| `analysis.compositing.alpha_premultiplication.v1` | reference_only | analysis guidance |
| `analysis.composition.eye_trace_bridge.v1` | reference_only | analysis guidance |
| `analysis.mask_tracking_edge_quality.v1` | reference_only | visual review guidance |
| `audio.loudness.dialogue_intelligibility.v1` | reference_only | audio guidance; no audio emitter |
| `look.color.restrained_native.v1` | reference_only | no calibrated creative mapping |
| `look.crt.old_television.v1` | validated | `look.old_television` native base recipe |
| `motion.ease_in_out_guidance.v1` | reference_only | no admitted easing encoding |
| `motion.focal.target_push.v1` | validated | `native.targeted_rotate_zoom`; confirmed target required |
| `motion.opacity.fade.v1` | validated | `motion.living_still` opacity construction |
| `motion.still.quiet_push.v1` | validated | `motion.living_still` affine construction |
| `process.review.representative_bakeoff.v1` | reference_only | review protocol |
| `safety.flash_pse_blocker.v1` | reference_only | safety gate |
| `transition.dissolve.short_natural.v1` | validated | canonical 12-frame native dissolve |
| `typography.caption_guidance.v1` | reference_only | no typography emitter |
| `typography.readability.captions.v1` | reference_only | no typography emitter |

The validated/reference-only split is **5/10**. The shipped sources file has
**153 unique HTTPS records across 54 categories** and is bundled with the app
alongside the strict card and treatment schemas.

## User-visible workflow

The installed app exposes the complete single-still foundation:

- command text and explicit editorial duration;
- local media admission and optional confirmed focal point;
- **Surprise Me** with zero to three admitted choices;
- per-option idea, exact native changes, preserved structure, editability,
  cost, privacy, safety, provenance, and digest disclosures;
- exact actions **Preview**, **Use This**, **Refine**, and **Compare**;
- source plus A/B/C comparison on one shared loop clock;
- semantic refinement through the truthful parameter inspector;
- option history and exact restore;
- automatic invalidation when source, duration, target, capability, catalog,
  schema, registry, or construction evidence drifts;
- admitted package and project export.

For one still with a confirmed focal target, the current deterministic option
probe demonstrates two options: Opacity fade and Old television / CRT. It
reports an honest semantic-diversity shortfall rather than padding toward the
up-to-three limit. Without a target, the set may shorten further rather than
substituting the center. Two-clip dissolve remains an emitter/admission path,
not a claim that the current single-still comparison viewer previews a
transition.

## Verification summary

- `make test`: **324 tests passed**, zero failures.
- `scripts/audit-core.py`: registry 4, strict treatment contract, 15 valid
  cards, 5 validated, 10 reference-only, zero forbidden patterns.
- Release Swift build: passed.
- Installed app: `/Users/marcboyer/Applications/FCPCommandConsole.app`, strict
  deep code-signature verification passed; sources, schema, and 15 cards are
  present in the bundle.
- Fresh post-fix export:
  `/Users/marcboyer/Movies/FCPCommandConsole/exports/standalone/3E43F9A8-4FFE-4698-8261-69AE79A2139D`.
  Its FCPXML parses, is exactly 4 seconds, preserves media SHA-256
  `48a7c0eda7057e1c7075b996914eae24e0ed46d014a4315aee3db1fc3bfa25f4`,
  and records the exact director wording in `provenance.json`.
- The copied isolated Final Cut executable—not the stock app—imported and
  opened the fresh `3E43F9A8` event in the disposable library. The live timeline
  was 4 seconds, the native Color Adjustments effect was present, and the
  opacity inspector changed from 100% at the start to 54.64% at 03:24 during
  the final fade.

The Final Cut import open panel changed only `NSOSPLastRootDirectory` in the
normal user preference plist, from the prior standalone-export folder bookmark
to this export folder. The isolation guard therefore correctly returned a
partial/failing verdict instead of a clean pass. The pre-run normalized value
was restored exactly (matching SHA-256
`588081f124276d527eed54d825efbdf00f5afc27d9bfc10c512d5508323cadbc`),
the post-import file was retained in the run's private provenance directory,
and a subsequent `--preflight-only` passed. No production library was opened.

## Remaining limitations

- No depth synthesis, masks, tracking, typography, captions, sound design, or
  audio treatment is implemented in this foundation.
- Old Television currently looks like a restrained base flicker/color recipe;
  the optional connected overlay lacks fresh Final Cut and perceptual proof.
- Color preview is indicative, not calibrated.
- Natural Dissolve's current canonical 12-frame route has automated evidence,
  but still needs a fresh real-Final-Cut import.
- Visual comparison proves shared native construction and absence of obvious
  crop/warp/halo failures on representative stills; it is not expert or
  population perceptual evidence.

## Next milestone

The next justified step is a rendered-preview and perceptual-evidence layer:
fresh real-Final-Cut proof for the canonical 12-frame dissolve and optional CRT
overlay, offline rendered A/B frames from the exact admitted channels, calibrated
color mappings, and only then additional validated cards. Depth, masking,
typography, and audio should remain separate admission milestones with their own
capability and evidence gates.
