# Phase 1 acceptance

Refreshed 2026-08-03 from checkpoint `c282b0f`. Phase 1 remains **incomplete:
0/4 Final Cut workflows accepted**.

## Verified offline and local-app facts

- `swift build` succeeded.
- `swift test` passed 94 tests with 0 failures.
- Schema v2 models, registry, deterministic parser/planner, validator, legacy
  quarantine, granular capability gate, local admission, role tokens,
  aspect-fit mapping, source preview, and inert package builder are implemented
  and tested.
- The standalone app has been installed at
  `/Users/marcboyer/Applications/FCPCommandConsole.app` with bundle identifier
  `com.marcboyer.FCPCommandConsole`; signature/resource checks passed.
- Local packages preserve source bytes and refuse stale/nonregular/symlinked
  sources, unsafe roots, operation collisions, and identity mismatch.
- Package writes are anchored to a descriptor on the vetted output root and
  published with `renameatx_np(RENAME_EXCL)`; a plan whose command, target, or
  role sources have drifted is refused before the output root is touched.
- The installer refuses symlinked, dangling, and non-bundle install targets and
  verifies the installed bundle after the swap.

None of these are Final Cut workflow acceptance.

## Final Cut evidence and manual gate

The installed environment is Final Cut Pro 12.3 build 450152. The v1 predecessor
crashed while importing `asset-clip`; crash report
`/Users/marcboyer/Library/Logs/DiagnosticReports/Final Cut Pro-2026-08-03-082455.ips`,
incident `42DFFCF1-9E45-41DA-992F-ADB212422B07`, operation
`A78B1B9D-60D7-4CD8-960B-FA9104C301E7`.

The immutable reduced v2 package at
`/Users/marcboyer/Movies/FCPCommandConsole/exports/roundtrip-spikes/CA7D0733-A435-498E-BD82-149CFF863FC3`
passed syntax/DTD checks only. All Final Cut manual semantic rows are unknown.

### The manual pass was executed on 2026-08-03 (23:19–23:28)

One pass, through the guarded isolated launcher against the reviewed copied
app, into the disposable library. Full results and the returned XML analysis
are in `docs/ROUNDTRIP_MANUAL_PASS.md`.

| Contract | Result |
| --- | --- |
| Import completed without error or crash | pass — the v1 `addAssetClip:` crash did not recur |
| asset admission | **pass** — both assets resolved with real uid/sig, correct durations, codecs detected |
| bare dissolve transition | **fail** — returned at `offset="0s"` with `enabled="0"` and a synthesized `<effect uid=""/>` |
| transition timing and handles | **fail** — 8s + 8s butt cut, no overlap, no handles |
| returned FCPXML round trip | partial — export works; the transition did not round-trip faithfully |

**Natural dissolve is not accepted.** It requires asset admission *and* bare
dissolve; bare dissolve failed. No capability gate moved: `SemanticProfile`
has no persisted contract store and defaults to an empty admitted set, so every
FCPXML pathway remains closed.

The result is nonetheless real progress. The v1 predecessor crashed during
`asset-clip` import and never reached semantics; the reduced v2 package
imported cleanly, which localises the remaining problem to transition
construction rather than asset handling. The probe's hypothesis — that a bare
`<transition>` element suffices — is disproven, and the returned XML says
precisely why: `offset` and the `filter-video` child are both `#IMPLIED` in the
DTD, so omitting them passes validation but yields a disabled placeholder at
time zero.

### The revision 3 pass was executed on 2026-08-04 (21:21–21:28)

Operation `6B8F8B1C-8171-4770-86C0-E5A859C3B32A`, same guarded isolated
launcher and disposable library (provenance `isolated-launch-preflight.JsuyVQ`).

| Contract | Result |
| --- | --- |
| Import completed without error or crash | pass |
| asset admission | **pass** — re-checked, not inherited: real uid/sig, correct durations, codecs detected |
| cross dissolve native semantics | **pass** — returned with our exact UID `FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265`, no `enabled="0"`, all four params verbatim, and Final Cut *added* an `FFAudioTransition` Audio Crossfade companion |
| transition timing and handles | **fail** — overlapping spine siblings; Final Cut truncated `clip-a` 7s → 6.5s and re-appended its 0.5s remainder as a third element |
| returned FCPXML round trip | partial — the effect round-tripped faithfully, the spine layout did not |

**The effect question is answered.** A `<transition>` carrying a real
`<effect>` resource and a `<filter-video>` reference is admitted as a native
Cross Dissolve. The unprompted Audio Crossfade companion is the proof: Final
Cut synthesizes one only for a transition it actually instantiated.

**The geometry question is not.** The incoming clip's offset was set to the
transition's offset, which made the two spine clips overlap by half the
transition duration. A spine is strictly sequential and cannot represent that.
The correct rule, read off the returned file: the transition offset is
`cut − T/2` (confirmed right), but the incoming clip's offset is `cut` — the
clips butt-join and the transition straddles the joint. That is a one-number
fix for revision 4.

The bad convention came from an OTIO-written fixture in `reference/`, not from
a Final Cut export. It was flagged in advance as the prime suspect for a
placement failure and it was the cause; that fixture is now untrusted for spine
geometry.

**Natural dissolve is still not accepted** — correct transition timing is part
of the workflow and it failed. No capability gate has been moved. The
effect-scoped contract taxonomy needs revisiting before one can be: what was
proven is a *fully specified* cross dissolve, not the "bare dissolve" the
taxonomy names, and revision 2 disproved the bare form outright.

Revisions 2 and 3 are spent evidence and were not modified, regenerated, or
retried.

### The revision 4 pass was executed on 2026-08-04 (21:42–21:46)

Operation `27EA1706-E765-4AC8-9487-54192E5F8DF3`, same guarded isolated
launcher and disposable library (provenance `isolated-launch-preflight.dOr4WG`).
It preserved revision 3's entire effect construction and changed one value —
the incoming clip's offset from `19500/3000s` to `21000/3000s`.

| Contract | Result |
| --- | --- |
| Import completed without error or crash | pass |
| asset admission | **pass** |
| cross dissolve native semantics | **pass** — exact UID, no `enabled="0"`, params verbatim, `FFAudioTransition` companion added |
| transition timing and handles | **pass** — two spine clips only, `clip-a` 0→7s, `clip-b` 7→14s, transition at `19500/3000s`, 14s sequence |
| returned FCPXML round trip | **pass** — every timing value returned with the same numeric value |

**This is the project's first Final Cut semantic acceptance.** Four revisions,
each changing one thing, established the construction rules: a `<transition>`
needs a real `<effect>` resource and a `<filter-video>` referencing it; the
transition offset is `cut − duration/2`; the adjacent clips **butt-join** at
the cut rather than overlapping, because a `<spine>` is strictly sequential;
and both clips need unused source beyond the joint.

Revisions 2, 3, and 4 are spent evidence and were not modified, regenerated, or
retried.

### Why no gate moved on this evidence alone

`ManualFCPXMLSemanticsEvidence.requiredContracts(for: .naturalDissolve)` is
`[.assetAdmission, .bareDissolveTransition]`. Asset admission is established.
`bare_dissolve_transition` is **not**, and cannot be: revision 2 tested exactly
that construct and Final Cut returned it disabled. The contract as named
describes something that does not work.

The taxonomy must therefore be corrected to name the construct the evidence
supports — a fully specified cross dissolve — before natural dissolve can be
assessed against it. Renaming a contract is not the same as admitting one, and
neither is done implicitly by a passing probe.

## Workflow matrix

| Workflow | Offline/local status | Final Cut acceptance |
| --- | --- | --- |
| Targeted rotate/zoom | planner/math/local point selection implemented | not accepted |
| Natural dissolve | registry + syntax packages through revision 4 | **Final Cut semantics observed to pass** — asset admission, native cross dissolve, correct timing, and a faithful round trip. Not yet an accepted workflow: the contract taxonomy names a construct (`bare_dissolve_transition`) that revision 2 disproved, and no gate has been moved. |
| Old Television | layered-media plan/composition/local package only | not accepted |
| Living Still | native-fallback plan/local package only | not accepted |

Do not report workflow success from a plan, DTD pass, package, source preview,
or app signature. Only a documented Final Cut import/export/readback/manual
result can advance an appropriate row.
