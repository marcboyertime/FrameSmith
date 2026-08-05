# FCPCommandConsole status

Checkpoint refreshed 2026-08-03 from local evidence. The code checkpoint is
commit `c282b0f` on branch `standalone-app`, which added the local-filesystem
hardening described in `docs/HANDOFF.md` section 4b.

## Verified implementation and local app facts

| Item | Evidence |
| --- | --- |
| Core build | `swift build` passed at checkpoint `c282b0f` |
| Test suite | `swift test`: 94 tests, 0 failures |
| Standalone app | `/Users/marcboyer/Applications/FCPCommandConsole.app` |
| Bundle identity | `com.marcboyer.FCPCommandConsole` |
| Signature | `codesign --verify --deep --strict` passed |
| Bundled resources | registry and schema resources present in the installed app |
| Process snapshot | PID `6515` was observed for the installed app; PIDs are drift-prone and must be rechecked |
| Current plan schema | exactly `2.0` |

The SwiftUI app is a local-media planning surface. It admits read-only local
movies/stills, computes SHA-256 identities, presents source-only previews,
collects an optional aspect-fit normalized point, plans against the local
registry, and can save an inert local plan/media package. It does not render an
effect or control Final Cut.

## Current plan taxonomy and gates

Schema 2.0 encodes only these representation values:

- `fcpxml_native`
- `layered_media`
- `motion_template`
- `external_editable_composition`
- `baked_render`

Schema 1.0 and the old raw values `fcp_native`,
`generated_asset_plus_fcp_native`, and `external_render_required` are
quarantined. They may receive a suggested migration class, but cannot become a
current executable/previewable plan; they must be replanned and validated as
schema 2.0. Unknown schema versions fail closed.

`CapabilityGate` is central. Current v2 plans may be used for local-only
preview and inert payload-neutral packaging. FCPXML preview/export remains
blocked without granular manual semantic contracts, and local-media tokens also
never establish Final Cut selection/spine/adjacency evidence. Contract evidence
is effect-scoped: asset admission, bare dissolve, transform keyframes, opacity
keyframes, native color adjustment, and connected overlay layers are separate.

## Inert package fact

`LocalPlanPackageBuilder` creates a non-overwriting UUID directory under
`~/Movies/FCPCommandConsole/exports/local-plan-packages/` by default. It stages
beside the target, checks safe roots and exact admitted slots, rehashes each
source before/copy/after, and publishes only on a complete match. A package
contains `EffectPlan.json`, `Manifest.json`, `Provenance.json`, `README.txt`,
and copied `Media/` files. It contains no `.fcpxml`, effect render, shell
command, or Final Cut compatibility claim.

Every one of those writes is anchored to a file descriptor opened on the vetted
output root (`service/DirectoryDescriptor.swift`), so an ancestor renamed or
replaced with a symlink after validation cannot redirect the staging, the media
copies, or the publish. The publish itself is a single
`renameatx_np(..., RENAME_EXCL)`: it is the commit point, it cannot overwrite
an existing entry or a dangling symlink, and a cancellation that arrives after
it is reported with the published path rather than dropped. A plan whose
command, target point, or role sources have drifted since it was made is
refused before the output root is touched.

## Final Cut evidence boundary

Final Cut Pro installed version: **12.3, build 450152**. This is environment
metadata, not acceptance evidence. Phase 1 remains **incomplete: 0/4 Final Cut
workflows accepted**.

The immutable reduced v2 round-trip package is:

`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/CA7D0733-A435-498E-BD82-149CFF863FC3`

The predecessor v1 import crashed during `asset-clip` import:

- report: `/Users/marcboyer/Library/Logs/DiagnosticReports/Final Cut Pro-2026-08-03-082455.ips`
- incident: `42DFFCF1-9E45-41DA-992F-ADB212422B07`
- predecessor operation: `A78B1B9D-60D7-4CD8-960B-FA9104C301E7`

**The v2 manual pass was executed on 2026-08-03 23:19–23:28** through the
guarded isolated launcher into the disposable library. It did not crash. Both
assets were admitted with real uid/sig, correct durations, and detected codecs,
so the v1 crash did not recur. The bare transition was **rejected**: Final Cut
returned it at `offset="0s"` with `enabled="0"` against a synthesized
`<effect uid=""/>`, and the two clips butt-cut at 8s with no overlap or handles.

Phase 1 therefore remains **incomplete: 0/4 Final Cut workflows accepted**.
Natural dissolve needs asset admission *and* bare dissolve; only the former was
observed. No capability gate moved. Full results, the returned XML analysis,
and revision 3 requirements are in `docs/ROUNDTRIP_MANUAL_PASS.md`.

Revision 2 is spent evidence and was not modified, regenerated, or retried.

**The revision 3 pass was executed on 2026-08-04 21:21–21:28** against
`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/6B8F8B1C-8171-4770-86C0-E5A859C3B32A`

Revision 3 kept everything Final Cut admitted in revision 2 and changed only
the transition: a real `<effect>` carrying the Cross Dissolve UID
`FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265`, a `filter-video` reference to
it, an explicit offset centred on the cut, and one-second handles.

**The Cross Dissolve was admitted.** It returned with our exact UID, no
`enabled="0"`, all four params verbatim, and an `FFAudioTransition` Audio
Crossfade companion that Final Cut added on its own — which it does only for a
transition it genuinely instantiated. Asset admission passed again on a
re-check.

**The spine geometry was rejected.** Revision 3 gave the incoming clip the same
offset as the transition, so the two spine clips overlapped by half the
transition duration. A spine is strictly sequential, so Final Cut truncated
`clip-a` from 7s to 6.5s and re-appended its orphaned 0.5s remainder after
`clip-b`. The correct rule, derived from the returned file: transition offset
`cut − T/2` is right, but the incoming clip's offset must be `cut` — the clips
butt-join and the transition straddles the joint. Revision 4 is a one-number
change.

The faulty convention came from an OTIO-written fixture in `reference/`, not a
Final Cut export; it is now untrusted for spine geometry.

Phase 1 remains **incomplete: 0/4 Final Cut workflows accepted**. Natural
dissolve needs correct transition timing and that row failed. No capability
gate has been moved, and the effect-scoped contract taxonomy needs revisiting
first — what was proven is a *fully specified* cross dissolve, not the "bare
dissolve" the taxonomy names.

Revisions 2 and 3 are spent evidence and were not modified, regenerated, or
retried. Full results and the returned XML analysis are in
`docs/ROUNDTRIP_MANUAL_PASS.md`.
