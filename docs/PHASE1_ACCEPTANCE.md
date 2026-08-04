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

**Revision 3 has been built** as operation
`6B8F8B1C-8171-4770-86C0-E5A859C3B32A` and awaits its manual pass. It supplies
the real Cross Dissolve effect UID, the `filter-video` reference, an explicit
offset centred on the cut, and one-second handles, while keeping every
construction Final Cut already admitted. Revision 2 was not modified,
regenerated, or retried. Nothing about revision 3's Final Cut behaviour may be
claimed until its own pass is run — its evidence ledger records every semantic
row as `unknown`, including asset admission.

## Workflow matrix

| Workflow | Offline/local status | Final Cut acceptance |
| --- | --- | --- |
| Targeted rotate/zoom | planner/math/local point selection implemented | not accepted |
| Natural dissolve | registry + reduced v2 syntax package; v2 imported cleanly but the bare transition was rejected as a disabled placeholder | not accepted — asset admission observed, bare dissolve failed |
| Old Television | layered-media plan/composition/local package only | not accepted |
| Living Still | native-fallback plan/local package only | not accepted |

Do not report workflow success from a plan, DTD pass, package, source preview,
or app signature. Only a documented Final Cut import/export/readback/manual
result can advance an appropriate row.
